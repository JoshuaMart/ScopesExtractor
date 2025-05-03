# frozen_string_literal: true

module ScopesExtractor
  # Normalizer module provides methods to standardize and validate scope formats
  # across different bug bounty platforms
  module Normalizer
    # Regular expression for validating IPv4 addresses
    IP_REGEX = /\A((?:\d{1,3}\.){3}(?:\d{1,3})\Z)/.freeze

    # Runs normalization of a scope value based on the platform
    # @param platform [String] The platform name (e.g., 'YesWeHack')
    # @param value [String] The scope value to normalize
    # @return [Array<String>] List of normalized scopes
    def self.run(platform, value)
      scope = global_normalization(value)

      normalized_scopes = case platform
                          when 'YesWeHack'
                            YesWeHack.normalization(scope)
                          when 'Intigriti'
                            Intigriti.normalization(scope)
                          when 'Hackerone'
                            Hackerone.normalization(scope)
                          when 'Bugcrowd'
                            Bugcrowd.normalization(scope)
                          else
                            []
                          end

      normalized_scopes.uniq!
      normalized_scopes.select do |s|
        Normalizer.valid?(s) || false
      end
    end

    # Validates if a scope value is a valid IP address or URI
    # @param value [String] The scope value to validate
    # @return [Boolean] True if the value is valid, false otherwise
    def self.valid?(value)
      value.match?(IP_REGEX) ? Parser.valid_ip?(value) : Parser.valid_uri?(value)
    end

    # Performs global normalization of a scope value
    # @param value [String] The scope value to normalize
    # @return [String] The normalized scope value
    def self.global_normalization(value)
      value = global_end_strip(value)

      # Remove protocol (http:// or https://) if string matches the pattern
      value = value.sub(%r{https?://}, '') if value.match?(%r{https?://\*\.})

      # Add "*" at the beginning if the string starts with a dot
      value = "*#{value}" if value.start_with?('.')

      # Return the lowercase string
      value.downcase
    end

    # Removes special characters from the end of a scope value
    # @param value [String] The scope value to process
    # @return [String] The processed scope value
    def self.global_end_strip(value)
      # Remove last two characters if the string ends with "/*"
      value = value[0..-2] if value.end_with?('/*')

      # Remove last character if the string ends with "/" and starts with "*."
      value = value[0..-2] if value.end_with?('/') && value.start_with?('*.')

      # Remove first character if the string starts with "*" but not "*."
      value[1..] if value.start_with?('*') && !value.start_with?('*.')
      value
    end
  end
end
