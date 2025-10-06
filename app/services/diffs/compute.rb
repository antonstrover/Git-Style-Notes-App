# frozen_string_literal: true

module Diffs
  class Compute
    class NotImplementedError < StandardError; end

    def initialize(version_a:, version_b:)
      @version_a = version_a
      @version_b = version_b
    end

    def call
      raise NotImplementedError, "Diff computation will be added in a later PR"
    end

    private

    attr_reader :version_a, :version_b

    # Future return format:
    # {
    #   additions: [...],
    #   deletions: [...],
    #   changes: [...]
    # }
  end
end
