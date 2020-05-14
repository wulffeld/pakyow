require_relative "../shared"

RSpec.describe "running multiple services in a container" do
  include_context "runnable container"

  shared_examples :examples do
    before do
      local = self

      container.service :foo do
        define_method :perform do
          loop do
            sleep 0.4

            local.write_to_parent("foo")
          end
        end
      end

      container.service :bar do
        define_method :perform do
          loop do
            sleep 0.41

            local.write_to_parent("bar")
          end
        end
      end
    end

    it "runs each service until the container is stopped" do
      run_container(timeout: 1)

      expect(read_from_child).to eq("foobarfoobar")
    end
  end

  context "forked container" do
    let(:run_options) {
      { strategy: :forked }
    }

    include_examples :examples
  end

  context "threaded container" do
    let(:run_options) {
      { strategy: :threaded }
    }

    include_examples :examples
  end
end

RSpec.describe "running multiple nested service in a container" do
  include_context "runnable container"

  shared_examples :examples do
    before do
      local = self

      container.service :foo do
        define_method :perform do
          local.write_to_parent("foo")

          local.run_container(local.container2, timeout: 1, parent: self)
        end
      end

      container2.service :bar do
        define_method :perform do
          loop do
            sleep 0.4

            local.write_to_parent("bar")
          end
        end
      end

      container2.service :baz do
        define_method :perform do
          loop do
            sleep 0.41

            local.write_to_parent("baz")
          end
        end
      end
    end

    let(:container2) {
      Pakyow::Runnable::Container.make(:test2)
    }

    it "runs the nested services until the top-level container is stopped" do
      run_container(timeout: 1)

      expect(result.scan(/foo/).count).to eq(1)
      expect(result.scan(/bar/).count).to eq(2)
      expect(result.scan(/baz/).count).to eq(2)
    end
  end

  context "forked container" do
    let(:run_options) {
      { strategy: :forked }
    }

    include_examples :examples
  end

  context "threaded container" do
    let(:run_options) {
      { strategy: :threaded }
    }

    include_examples :examples
  end
end
