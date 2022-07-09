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
    def self._new(entry_point, warn_on_extra_files:)
      new(entry_point, warn_on_extra_files: warn_on_extra_files)
    end

    # @sig (String, bool) -> void
    def initialize(entry_point, warn_on_extra_files:)
      super()

      @entry_point         = File.expand_path(entry_point)
      @lib, @namespaces    = find_lib
      @inflector           = GemInflector.new(@entry_point)
      @warn_on_extra_files = warn_on_extra_files
      @tag                 = File.basename(@entry_point, ".rb")

      if @namespaces.any?
        @tag = [*@namespaces, @tag].join('-')
        ensure_namespaces_are_already_defined
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

      Pathname.new(File.dirname(@entry_point)).ascend do |dir|
        basename = dir.basename.to_s
        if basename == "lib"
          return [dir.to_s, namespaces]
        else
          namespaces.unshift(basename)
        end
      end

      raise Zeitwerk::LibNotFound.new(@entry_point)
    end

    def ensure_namespaces_are_already_defined
      dir = @lib
      parent = Object
      @namespaces.each do |namespace|
        dir = File.join(dir, namespace)
        cname = @inflector.camelize(namespace, dir).to_sym
        begin
          parent = cget(parent, cname)
        rescue ::NameError => e
          if e.receiver == parent && e.name == cname
            raise Zeitwerk::NamespaceNotFound.new(cpath(parent, cname))
          else
            raise
          end
        end
      end
    end

    # @sig () -> void
    def warn_on_extra_files
      expected_namespace_dir = if @namespaces.empty?
        @entry_point.delete_suffix(".rb")
      else
        File.join(@lib, @namespaces[0])
      end

      ls(@lib) do |basename, abspath|
        next if abspath == @entry_point
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
