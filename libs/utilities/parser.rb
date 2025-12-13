# frozen_string_literal: true

require 'ipaddr'
require 'uri'
require_relative '../platforms/config'

module ScopesExtractor
  # Parser module provides utilities for parsing and validating various data formats
  # including JSON, IP addresses, and URIs
  module Parser
    # Custom error for URIs containing wildcards
    class WildcardURIError < StandardError; end

    class << self
      # Loads the parser configuration
      # Uses memoization to avoid loading the config multiple times
      # @return [Hash] Parser configuration options including exclusions
      def parser_config
        @parser_config ||= Config.load[:parser]
      end

      # Gets scope exclusions from parser config
      # @return [Array<String>] List of scope exclusion patterns
      def exclusions
        parser_config[:scope_exclusions]
      end

      # Parses a JSON string into a Ruby object
      # @param data [String] JSON string to parse
      # @return [Hash, Array, nil] Parsed JSON object or nil if parsing fails
      def json_parse(data)
        JSON.parse(data)
      rescue JSON::ParserError
        Discord.log_warn("JSON parsing error : #{data}")
        nil
      end

      # Validates if a string represents a valid IP address
      # @param value [String] The IP address to validate
      # @return [Boolean] True if the value is a valid IP address, false otherwise
      def valid_ip?(value)
        IPAddr.new(value)
        true
      rescue IPAddr::InvalidAddressError
        Discord.log_warn("Bad IPAddr for '#{value}'")
        false
      end

      # Validates if a string represents a valid URI
      # @param value [String] The URI to validate
      # @return [Boolean] True if the value is a valid URI, false otherwise
      def valid_uri?(value)
        return false if excluded?(value)

        validate_uri_format?(value)
      rescue URI::InvalidURIError, WildcardURIError
        log_uri_error(value)
        false
      end

      private

      # Checks if value matches any exclusion pattern
      # @param value [String] The value to check
      # @return [Boolean] True if value should be excluded
      def excluded?(value)
        exclusions.any? { |exclusion| value.include?(exclusion) }
      end

      # Validates the URI format and checks for invalid wildcards
      # @param value [String] The URI to validate
      # @return [Boolean] True if valid
      def validate_uri_format?(value)
        check_wildcard(value)
        url = normalize_url(value)
        !!URI.parse(url)&.host
      end

      # Checks for invalid wildcard patterns
      # @param value [String] The value to check
      # @raise [WildcardURIError] If value contains invalid wildcard
      def check_wildcard(value)
        raise WildcardURIError, 'contains wildcard' if value.include?('*') && !value.start_with?('*.')
      end

      # Normalizes URL by removing wildcard prefix for parsing
      # @param value [String] The URL value
      # @return [String] Normalized URL
      def normalize_url(value)
        url = value.start_with?('*.') ? value.sub('*.', '') : value
        url.start_with?('http') ? url : "http://#{url}"
      end

      # Logs URI validation error if notifications are enabled
      # @param value [String] The invalid URI value
      def log_uri_error(value)
        Discord.log_warn("Bad URI for '#{value}'") if parser_config[:notify_uri_errors]
      end
    end
  end
end
