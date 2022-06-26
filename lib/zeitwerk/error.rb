# frozen_string_literal: true

module Zeitwerk
  class Error < StandardError
  end

  class ReloadingDisabledError < Error
    def initialize
      super("can't reload, please call loader.enable_reloading before setup")
    end
  end

  class NameError < ::NameError
  end

  class LibNotFound < Error
    def initialize(root_file)
      super("Gem lib directory not found for #{root_file}")
    end
  end
end
