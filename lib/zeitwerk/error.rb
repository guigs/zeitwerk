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
    def initialize(entry_point)
      super("Gem lib directory not found for #{entry_point}")
    end
  end

  class NamespaceNotFound < Error
    def initialize(namespace)
      super(<<~MSG)
        The namespace #{namespace} was not found. Please load it before
        setting up Zeitwerk. That way we make sure the gem reopens it, instead of
        creating it.
      MSG
    end
  end
end
