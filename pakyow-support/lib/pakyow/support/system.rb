# frozen_string_literal: true

module Pakyow
  module Support
    # Information about the local system.
    #
    # @api private
    module System
      module_function

      def current_path
        @__current_path ||= Pathname.new(File.expand_path("."))
      end

      def current_path_string
        @__current_path_string ||= current_path.to_s
      end

      def gemfile_path
        @__gemfile_path ||= current_path.join("Gemfile")
      end

      def gemfile_path_string
        @__gemfile_path_string ||= gemfile_path.to_s
      end

      def gemfile?
        gemfile_path.exist?
      end

      def bundler_gem_path
        @__bundler_gem_path ||= Bundler.bundle_path.join("bundler/gems")
      end

      def bundler_gem_path_string
        @__bundler_gem_path_string ||= bundler_gem_path.to_s
      end

      def local_framework_path
        @__local_framework_path ||= Pathname.new(File.expand_path("../../../../../", __FILE__))
      end

      def local_framework_path_string
        @__local_framework_path_string ||= local_framework_path.to_s
      end

      def ruby_gem_path
        @__ruby_gem_path ||= Pathname.new(Gem.dir).join("gems")
      end

      def ruby_gem_path_string
        @__ruby_gem_path_string ||= ruby_gem_path.to_s
      end
    end
  end
end
