# frozen_string_literal: true

module ScopesExtractor
  # Normalizer module for standardizing domain formats
  module Normalizer
    # Intigriti module provides specialized normalization functions for Intigriti platform scopes
    module Bugcrowd
      # Normalize a domain scope string into standardized format(s)
      # @param value [String] The raw domain scope string
      # @return [Array<String>] List of normalized domain scopes
      def self.normalization(value)
        value.strip!

        [value]
      end
    end
  end
end
