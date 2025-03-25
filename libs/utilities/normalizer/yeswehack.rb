# frozen_string_literal: true

module ScopesExtractor
  # Normalizer module for standardizing domain formats
  module Normalizer
    # YesWeHack module provides specialized normalization functions for YesWeHack platform scopes
    module YesWeHack
      # Patterns indicating special cases that should not be normalized
      EXCLUDED_PATTERNS = [
        'endpoints on our sites',
        'special scenarios',
        'core services',
        'see program description',
        'see description'
      ].freeze

      # Regex patterns for matching specific domain formats
      MULTI_TLDS = %r{(?<prefix>https?://|wss?://|\*\.)?(?<middle>[\w.-]+\.)\((?<tlds>[a-z.|]+)}.freeze

      # Normalize a domain scope string into standardized format(s)
      # @param value [String] The raw domain scope string
      # @return [Array<String>] List of normalized domain scopes
      def self.normalization(value)
        return [] if excluded_pattern?(value)

        normalized_scopes = []

        # Process domains with multiple TLDs in parentheses
        if (match = value.match(MULTI_TLDS))
          normalized_scopes.concat(normalize_with_tlds(match))
        end

        normalized_scopes << value if normalized_scopes.empty?

        normalized_scopes
      end

      # Check if value contains any excluded patterns
      # @param value [String] The scope value to check
      # @return [Boolean] True if an excluded pattern is found
      def self.excluded_pattern?(value)
        EXCLUDED_PATTERNS.any? { |pattern| value.include?(pattern) }
      end

      # Normalize domains with multiple TLDs specified in parentheses
      # @param match [MatchData] Regex match data from MULTI_TLDS
      # @return [Array<String>] List of normalized domains
      def self.normalize_with_tlds(match)
        match[:tlds].split('|').map { |tld| "#{match[:prefix]}#{match[:middle]}#{tld}" }
      end
    end
  end
end
