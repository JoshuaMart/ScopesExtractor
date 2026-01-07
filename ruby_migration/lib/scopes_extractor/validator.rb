# frozen_string_literal: true

module ScopesExtractor
  module Validator
    def self.valid_web_target?(value, type)
      # We only enforce strict format for web/api types
      return true unless %w[web api].include?(type.to_s)

      val = value.to_s.strip

      # 1. Must have at least one dot OR be a valid URL (to support http://localhost)
      return false unless val.include?('.') || val.match?(%r{^https?://})

      # 2. Must NOT contain any spaces
      return false if val.include?(' ')

      # 3. Must NOT contain sentence punctuation, brackets, or chevrons
      return false if val.match?(/[!?()\[\]{}<>]/)

      # 4. Wildcards are only allowed at the start (e.g. *.example.com)
      # Reject internal wildcards like "sub.*.domain.com"
      return false if val.include?('*') && !val.start_with?('*.')

      # 5. Minimum length (e.g., "a.bc")
      return false if val.length < 4

      true
    end
  end
end
