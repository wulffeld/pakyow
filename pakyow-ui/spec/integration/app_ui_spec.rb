require_relative 'support/int_helper'

context 'after the app is initialized' do
  before do
    Pakyow::App.stage(:test)
  end

  let :app_ui do
    Pakyow.app.instance_variable_get(:@ui)
  end

  it 'inits ui and makes it available on the app' do
    expect(app_ui.class).to eq Pakyow::UI::UI
  end

  context 'after the app is loaded' do
    after do
      Pakyow.app.reload
    end

    it 'loads ui' do
      expect(app_ui).to receive(:load).with(Pakyow.app.mutators, Pakyow.app.mutables)
    end
  end

  context 'before routing' do
    before do
      Pakyow.app.process(Rack::MockRequest.env_for('/'))
    end

    let :context do
      Pakyow.app.context
    end

    it 'sets ui on the context' do
      expect(context.ui.class).to eq(Pakyow::UI::UI)
    end

    it 'duplicates the ui' do
      expect(context.ui.object_id).not_to eq(app_ui.object_id)
    end
  end
end

