# frozen_string_literal: true

require 'ipaddr'
require 'uri'
require_relative '../platforms/config'

module ScopesExtractor
  # Parser module provides utilities for parsing and validating various data formats
  # including JSON, IP addresses, and URIs
  module Parser
    class << self
      # Loads the parser configuration
      # Uses memoization to avoid loading the config multiple times
      # @return [Hash] Parser configuration options including exclusions
      def parser_config
        @parser_config ||= Config.load[:parser]
      end

      # Gets exclusions from parser config
      # @return [Array<String>] List of exclusion patterns
      def exclusions
        parser_config[:exclusions]
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
        return false if exclusions.any? { |exclusion| value.include?(exclusion) }

        url = value.start_with?('http') ? value : "http://#{value.sub('*.', '')}"

        !!URI.parse(url)&.host
      rescue URI::InvalidURIError
        Discord.log_warn("Bad URI for '#{value}'") if parser_config[:notify_uri_errors]
        false
      end
    end
  end
end
