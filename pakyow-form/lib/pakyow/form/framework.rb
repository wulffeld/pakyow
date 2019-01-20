# frozen_string_literal: true

require "json"

require "pakyow/framework"

require "pakyow/support/extension"
require "pakyow/support/inflector"

module Pakyow
  module Form
    module ConnectionHelpers
      def form
        get(:__form)
      end
    end

    class Framework < Pakyow::Framework(:form)
      def boot
        object.class_eval do
          isolated :Controller do
            action :clear_form_errors do
              if connection.form
                data.ephemeral(:errors, form_id: connection.form[:id]).set([])
              end
            end
          end

          isolated :ViewRenderer do
            action :set_form_framework_metadata, before: :embed_form_metadata do
              presenter.forms.each do |form|
                form.view.label(:metadata)[:binding] = [form.view.label(:binding)].concat(form.view.label(:channel)).join(":")
                form.view.label(:metadata)[:origin] = @connection.form.to_h[:origin] || @connection.fullpath
              end
            end
          end

          isolated :Connection do
            include ConnectionHelpers
          end

          handle InvalidData, as: :bad_request do |error|
            if connection.form
              errors = error.verifier.messages.flat_map { |_type, field_messages|
                field_messages.flat_map { |field, messages|
                  messages.map { |message|
                    { field: field, message: "#{Support.inflector.humanize(field)} #{message}" }
                  }
                }
              }

              if app.class.includes_framework?(:ui) && ui?
                data.ephemeral(:errors, form_id: connection.form[:id]).set(errors)
              else
                connection.set :__form_errors, errors

                # Expose submitted values to be presented in the form.
                #
                params.reject { |key| key == :form }.each do |key, value|
                  expose key, value, for: connection.form[:binding].to_s.split(":", 2)[1]
                end

                reroute connection.form[:origin], method: :get, as: :bad_request
              end
            else
              reject
            end
          end

          component :form do
            def perform
              errors = if connection.values.include?(:__form_errors)
                connection.get(:__form_errors)
              else
                []
              end

              expose :form_binding, connection.form.to_h[:binding]
              expose :form_errors, data.ephemeral(:errors, form_id: connection.get(:__form_ids).shift).set(errors)
            end

            presenter do
              def perform
                if form_binding.nil? || form_binding == view.channeled_binding_name
                  classify_form
                  classify_fields
                  present_errors(form_errors)
                end
              end

              private

              def classify_form
                if form_errors.any?
                  attrs[:class] << :errored
                else
                  attrs[:class].delete(:errored)
                end
              end

              def classify_fields
                errored_fields = form_errors.map { |error|
                  error[:field]
                }

                view.binding_props.map { |prop|
                  prop.label(:binding)
                }.each do |binding_name|
                  if errored_fields.include?(binding_name)
                    find(binding_name).attrs[:class] << :errored
                  else
                    find(binding_name).attrs[:class].delete(:errored)
                  end
                end
              end

              def present_errors(errors)
                find(:error) do |view|
                  view.present(errors)
                end
              end
            end
          end
        end
      end
    end
  end
end
