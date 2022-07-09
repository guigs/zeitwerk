# frozen_string_literal: true

module Zeitwerk
  class GemInflector < Inflector
    # @sig (String) -> void
    def initialize(entry_point)
      namespace     = File.basename(entry_point, ".rb")
      parent_dir    = File.dirname(entry_point)
      @version_file = File.join(parent_dir, namespace, "version.rb")
    end

    # @sig (String, String) -> String
    def camelize(basename, abspath)
      abspath == @version_file ? "VERSION" : super
    end
  end
end
