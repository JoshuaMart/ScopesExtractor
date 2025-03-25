# frozen_string_literal: true

require 'faraday'
require 'faraday-cookie_jar'

module ScopesExtractor
  # HttpClient module provides a simplified interface for making HTTP requests
  # with cookie support and consistent error handling
  module HttpClient
    # Initialize Faraday client with cookie jar support
    @client = Faraday.new do |builder|
      builder.use :cookie_jar
      builder.adapter Faraday.default_adapter
    end

    # Performs an HTTP GET request
    # @param url [String] The URL to request
    # @param options [Hash] Request options including headers
    # @return [Faraday::Response, nil] Response object if successful
    def self.get(url, options = {})
      headers = options[:headers]

      @client.get(url, nil, headers)
    end

    # Performs an HTTP POST request
    # @param url [String] The URL to request
    # @param options [Hash] Request options including body and headers
    # @return [Faraday::Response, nil] Response object if successful
    def self.post(url, options = {})
      body = options[:body]
      headers = options[:headers]

      @client.post(url, body, headers)
    end
  end
end
