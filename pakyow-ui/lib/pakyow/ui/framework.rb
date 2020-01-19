# frozen_string_literal: true

require "concurrent/executor/single_thread_executor"

require "pakyow/framework"

require "pakyow/application/helpers/ui"

require "pakyow/application/behavior/ui/logging"
require "pakyow/application/behavior/ui/recording"
require "pakyow/application/behavior/ui/rendering"
require "pakyow/application/behavior/ui/timeouts"

require "pakyow/presenter/renderer/behavior/ui/install_transforms"

require "pakyow/support/deep_freeze"

module Pakyow
  module UI
    class Framework < Pakyow::Framework(:ui)
      # @api private
      module PresenterForContext
        def presenter_for_context(presenter_class, context)
          if context.presentables.include?(:__ui_transform)
            instance = find_ui_presenter_for(presenter_class).new(
              context.view, app: context.app, presentables: context.presentables
            )

            instance.instance_variable_set(:@calls, context.calls)
            instance
          else
            super
          end
        end
      end

      def boot
        object.class_eval do
          register_helper :passive, Application::Helpers::UI

          include Application::Behavior::UI::Logging
          include Application::Behavior::UI::Recording
          include Application::Behavior::UI::Rendering
          include Application::Behavior::UI::Timeouts

          isolated :Renderer do
            include Presenter::Renderer::Behavior::UI::InstallTransforms
          end

          prepend PresenterForContext

          ui_renderer = Class.new(isolated(:Renderer)) do
            def marshal_load(state)
              deserialize(state)
              @presenter_class = @app.find_ui_presenter_for(@presenter_class)
              initialize_presenter
            end

            def perform(*)
              @presenter.to_html
            end
          end

          # Delete the render_components build step since ui will not be invoking the component.
          #
          ui_renderer.__build_fns.delete_if { |fn|
            fn.source_location[0].end_with?("render_components.rb")
          }

          isolate(ui_renderer, as: Support::ObjectName.build("UIRenderer"))

          after "initialize" do
            config.data.subscriptions.version = top.config.version
          end

          # @api private
          attr_reader :ui_executor

          extend Support::DeepFreeze
          insulate :ui_executor

          after "initialize" do
            @ui_executor = Concurrent::SingleThreadExecutor.new(
              auto_terminate: false,
            )
          end
        end
      end
    end
  end
end
