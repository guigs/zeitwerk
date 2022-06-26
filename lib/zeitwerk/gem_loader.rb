# frozen_string_literal: true

require "pathname"

module Zeitwerk
  # @private
  class GemLoader < Loader
    # Users should not create instances directly, the public interface is
    # `Zeitwerk::Loader.for_gem`.
    private_class_method :new

    # @private
    # @sig (String, bool) -> Zeitwerk::GemLoader
    def self._new(root_file, warn_on_extra_files:)
      new(root_file, warn_on_extra_files: warn_on_extra_files)
    end

    # @sig (String, bool) -> void
    def initialize(root_file, warn_on_extra_files:)
      super()

      @root_file           = File.expand_path(root_file)
      @lib, @namespaces    = find_lib
      @inflector           = GemInflector.new(@root_file)
      @warn_on_extra_files = warn_on_extra_files

      @tag = File.basename(@root_file, ".rb")
      if @namespaces.any?
        @tag = [*@namespaces, @tag].join('-')
        optional_top_level_entrypoint = File.join(@lib, "#{@tag}.rb")
        if File.exist?(optional_top_level_entrypoint)
          ignore(optional_top_level_entrypoint)
        end
      end

      push_dir(@lib)
    end

    # @sig () -> void
    def setup
      warn_on_extra_files if @warn_on_extra_files
      super
    end

    private

    def find_lib
      namespaces = []

      Pathname.new(File.dirname(@root_file)).ascend do |dir|
        basename = dir.basename.to_s
        if basename == "lib"
          return [dir.to_s, namespaces]
        else
          namespaces.unshift(basename)
        end
      end

      raise Zeitwerk::LibNotFound.new(@root_file)
    end

    # @sig () -> void
    def warn_on_extra_files
      expected_namespace_dir = if @namespaces.empty?
        @root_file.delete_suffix(".rb")
      else
        File.join(@lib, @namespaces[0])
      end

      ls(@lib) do |basename, abspath|
        next if abspath == @root_file
        next if abspath == expected_namespace_dir

        basename_without_ext = basename.delete_suffix(".rb")
        cname = inflector.camelize(basename_without_ext, abspath)
        ftype = dir?(abspath) ? "directory" : "file"

        warn(<<~EOS)
          WARNING: Zeitwerk defines the constant #{cname} after the #{ftype}

              #{abspath}

          To prevent that, please configure the loader to ignore it:

              loader.ignore("\#{__dir__}/#{basename}")

          Otherwise, there is a flag to silence this warning:

              Zeitwerk::Loader.for_gem(warn_on_extra_files: false)
        EOS
      end
    end
  end
end
