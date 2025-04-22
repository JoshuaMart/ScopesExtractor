# frozen_string_literal: true

module ScopesExtractor
  # Normalizer module for standardizing domain formats
  module Normalizer
    # Intigriti module provides specialized normalization functions for Intigriti platform scopes
    module Intigriti
      # Normalize a domain scope string into standardized format(s)
      # @param value [String] The raw domain scope string
      # @return [Array<String>] List of normalized domain scopes
      def self.normalization(value)
        value = value.strip
        value.sub!(/^\*(\s\.|\.?\s)/, '*.')

        if value.include?(' / ')
          normalize_with_slash(value)
        else
          [value]
        end
      end

      # Extracts the domain when a slash ' / ' is present
      # @param value [String] The raw domain scope string with slash
      # @return [String] The normalized domain without description
      def self.normalize_with_slash(value)
        value.split(' / ')
      end
    end
  end
end
