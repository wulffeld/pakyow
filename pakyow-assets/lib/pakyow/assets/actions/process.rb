# frozen_string_literal: true

module Pakyow
  module Assets
    module Actions
      # Pipeline Action that processes assets at request time.
      #
      # This is intended for development use, please don't use it in production.
      # Instead, precompile assets into the public directory.
      #
      class Process
        def initialize(_)
        end

        def call(connection)
          if connection.app.config.assets.process && asset = find_asset(connection)
            connection.set_response_header("Content-Type", asset.mime_type)
            connection.body = asset.dup
            connection.halt
          end
        end

        private

        def find_asset(connection)
          connection.app.state_for(:asset).find { |asset|
            asset.public_path == connection.path
          }
        end
      end
    end
  end
end
