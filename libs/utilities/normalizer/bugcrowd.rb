# frozen_string_literal: true

module ScopesExtractor
  # Normalizer module for standardizing domain formats
  module Normalizer
    # Bugcrowd module provides specialized normalization functions for Bugcrowd platform scopes
    module Bugcrowd
      # Normalize a domain scope string into standardized format(s)
      # @param value [String] The raw domain scope string
      # @return [Array<String>] List of normalized domain scopes
      def self.normalization(value)
        value = value.strip

        if value.include?(' - ')
          [normalize_with_dash(value)]
        else
          [value]
        end
      end

      # Extracts the domain part before a dash and description
      # @param value [String] The raw domain scope string with dash
      # @return [String] The normalized domain without description
      def self.normalize_with_dash(value)
        value.split(' - ').first.strip
      end
    end
  end
end
