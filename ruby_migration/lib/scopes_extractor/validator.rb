# frozen_string_literal: true

module ScopesExtractor
  module Validator
    def self.valid_web_target?(value, type)
      # We only enforce strict format for web/api types
      return true unless %w[web api].include?(type.to_s)

      val = value.to_s.strip

      return false unless valid_basic_structure?(val)
      return false unless valid_wildcard_usage?(val)

      true
    end

    def self.valid_basic_structure?(val)
      # 1. Must have at least one dot OR be a valid URL (to support http://localhost)
      return false unless val.include?('.') || val.match?(%r{^https?://})

      # 2. Must NOT contain any spaces
      return false if val.include?(' ')

      # 3. Must NOT contain sentence punctuation, brackets, or chevrons
      return false if val.match?(/[!?()\[\]{}<>]/)

      # 4. Minimum length (e.g., "a.bc")
      return false if val.length < 4

      true
    end

    def self.valid_wildcard_usage?(val)
      return true unless val.include?('*')

      # 1. Wildcards must be at start only: "*.example.com"
      return false unless val.start_with?('*.')

      # 2. No double wildcards: "*.sub*.example.com"
      return false if val.count('*') > 1

      # 3. No paths allowed in wildcard domains: "*.example.com/login"
      return false if val.include?('/')

      # 4. Domain part cannot start with a hyphen: "*.-example.com"
      domain_part = val[2..]
      return false if domain_part&.start_with?('-')

      true
    end
  end
end
