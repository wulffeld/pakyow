# frozen_string_literal: true

module Pakyow
  module Presenter
    module Helpers
      module Rendering
        def render(path = request.env["pakyow.endpoint"] || request.path, as: nil, layout: nil, mode: :default)
          app.isolated(:ViewRenderer).render(
            @connection,
            templates_path: path,
            presenter_path: as,
            layout: layout,
            mode: mode
          )
        end
      end
    end
  end
end
