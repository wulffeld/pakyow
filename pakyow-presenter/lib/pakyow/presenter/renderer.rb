# frozen_string_literal: true

require "pakyow/support/hookable"
require "pakyow/support/core_refinements/string/normalization"

module Pakyow
  module Presenter
    module RenderHelpers
      def render(path = request.env["pakyow.endpoint"] || request.path, as: nil, layout: nil, mode: :default)
        app.class.const_get(:Renderer).new(@connection, path: path, as: as, layout: layout, mode: mode).perform
      end

      NOT_PASSED = Object.new
      def expose(name, default_value = NOT_PASSED, options = {})
        if within = options[:within]
          name = :"#{name};__within__:#{within}"
        end

        if default_value.equal?(NOT_PASSED)
          super name
        else
          super name, default_value
        end
      end
    end

    class Renderer
      class << self
        def perform_for_connection(connection)
          if implicitly_render?(connection)
            begin
              catch :halt do
                new(connection, implicit: true).perform
              end
            rescue MissingPage => error
              implicit_error = ImplicitRenderingError.new("Could not implicitly render at path `#{connection.path}'")
              implicit_error.context = connection.path
              implicit_error.set_backtrace(error.backtrace)
              connection.set(:error, implicit_error)
              connection.status = 404

              catch :halt do
                if Pakyow.env?(:production)
                  connection.app.class.const_get(:Controller).new(connection).trigger(404)
                else
                  new(connection, path: "/development/500").perform
                end
              end
            end
          end
        end

        def implicitly_render?(connection)
          !connection.rendered? &&
            connection.response.status == 200 &&
            connection.request.method == :get &&
            connection.request.format == :html
        end
      end

      include Support::Hookable
      known_events :render

      using Support::Refinements::String::Normalization

      attr_reader :presenter

      def initialize(connection, path: nil, as: nil, layout: nil, mode: :default, implicit: false)
        @connection, @implicit = connection, implicit

        path = String.normalize_path(path || default_path)
        as = String.normalize_path(as) if as

        unless info = find_info(path)
          error = MissingPage.new("No view at path `#{path}'")
          error.context = path
          raise error
        end

        # Finds a matching layout across template stores.
        #
        if layout && layout = layout_with_name(layout)
          info[:layout] = layout.dup
        end

        @presenter = (find_presenter(as || path) || ViewPresenter).new(
          binders: @connection.app.state_for(:binder),
          **info
        )

        @presenter.install_endpoints(
          endpoints_for_environment,
          current_endpoint: @connection.endpoint,
          setup_for_bindings: rendering_prototype?
        )

        if rendering_prototype?
          mode = @connection.params[:mode] || :default
        end

        @presenter.place_in_mode(mode)

        if rendering_prototype?
          @presenter.insert_prototype_bar(mode)
        else
          @presenter.cleanup_prototype_nodes
          @presenter.create_template_nodes
        end
      end

      def perform
        if @presenter.class == ViewPresenter
          find_and_present_presentables(@connection.values)
        else
          define_presentables(@connection.values)
        end

        performing :render do
          @connection.body = StringIO.new(
            @presenter.to_html
          )
        end

        @connection.rendered
      end

      protected

      def rendering_implicitly?
        @implicit == true
      end

      def rendering_prototype?
        Pakyow.env?(:prototype)
      end

      # We still mark endpoints as active when running in the prototype environment, but we don't
      # want to replace anchor hrefs, form actions, etc with backend routes. This gives the designer
      # control over how the prototype behaves.
      #
      def endpoints_for_environment
        if rendering_prototype?
          Endpoints.new
        else
          @connection.app.endpoints
        end
      end

      def default_path
        @connection.env["pakyow.endpoint"] || @connection.path
      end

      def find_info(path)
        collapse_path(path) do |collapsed_path|
          if info = info_for_path(collapsed_path)
            return info
          end
        end
      end

      def find_presenter(path)
        unless rendering_prototype?
          collapse_path(path) do |collapsed_path|
            if presenter = presenter_for_path(collapsed_path)
              return presenter
            end
          end
        end

        nil
      end

      def info_for_path(path)
        @connection.app.state_for(:templates).lazy.map { |store|
          store.info(path)
        }.find(&:itself)
      end

      def layout_with_name(name)
        @connection.app.state_for(:templates).lazy.map { |store|
          store.layout(name)
        }.find(&:itself)
      end

      def presenter_for_path(path)
        @connection.app.state_for(:presenter).find { |presenter|
          presenter.path == path
        }
      end

      def collapse_path(path)
        yield path; return if path == "/"

        yield path.split("/").keep_if { |part|
          part[0] != ":"
        }.join("/")

        nil
      end

      def define_presentables(presentables)
        # TODO: handle within

        presentables.each do |name, value|
          @presenter.define_singleton_method name do
            value
          end
        end
      end

      def find_and_present_presentables(presentables)
        presentables.each do |name, value|
          if name.to_s.include?(";__within__:")
            name, within = name.to_s.split(";__within__:")
          end

          [name, Support.inflector.singularize(name)].each do |name_varient|
            target = if within && node = find_container_or_partial_with_name(within)
              presenter.presenter_for(View.from_object(StringDoc.from_nodes([node])))
            else
              presenter
            end

            if found = target.find(name_varient)
              found.present(value); break
            end
          end
        end
      end

      def find_container_or_partial_with_name(name)
        name = name.to_sym
        (presenter.view.object.find_significant_nodes(:container) + presenter.view.object.find_significant_nodes(:partial)).find { |node|
          node.label(:container) == name || node.label(:partial) == name
        }
      end
    end
  end
end
