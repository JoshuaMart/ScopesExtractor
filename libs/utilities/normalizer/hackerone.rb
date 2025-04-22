# frozen_string_literal: true

module ScopesExtractor
  # Normalizer module for standardizing domain formats
  module Normalizer
    # Hackerone module provides specialized normalization functions for Hackerone platform scopes
    module Hackerone
      # Normalize a domain scope string into standardized format(s)
      # @param value [String] The raw domain scope string
      # @return [Array<String>] List of normalized domain scopes
      def self.normalization(value)
        value = value.strip

        if value.include?(',')
          value.split(',')
        else
          [value]
        end
      end
    end
  end
end
