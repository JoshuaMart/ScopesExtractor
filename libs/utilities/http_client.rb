# frozen_string_literal: true

require 'typhoeus'

module ScopesExtractor
  # HttpClient module provides a simplified interface for making HTTP requests
  # with cookie support and consistent error handling
  module HttpClient
    Typhoeus::Config.user_agent = 'curl/8.7.1'
    @cookie_jar = File.join(__dir__, '../db/cookies.txt')

    # Clears the cookie jar file by either truncating if it exists or creating a new empty file
    # @return [Boolean] True if cookie jar was successfully cleared
    def self.clear_cookie_jar
      File.truncate(@cookie_jar, 0) if File.exist?(@cookie_jar)
      true
    rescue StandardError => e
      Discord.log_warn("Error clearing cookie jar: #{e.message}")
      false
    end

    # Common request options used for both GET and POST requests
    # @param method [Symbol] HTTP method (:get or :post)
    # @param options [Hash] Request-specific options
    # @return [Hash] Combined request options
    def self.build_request_options(method, options = {})
      {
        method: method,
        headers: options[:headers] || {},
        followlocation: options[:follow_location] || false,
        timeout: 30, # Default timeout
        cookiefile: @cookie_jar,
        cookiejar: @cookie_jar,
        body: options[:body] # Will be nil for GET requests
      }.compact
    end

    # Performs an HTTP request with automatic retry for specific error conditions
    # @param method [Symbol] HTTP method to use
    # @param url [String] The URL to request
    # @param options [Hash] Request options including headers, body, max_retries, and retry_delay
    # @return [Typhoeus::Response, nil] Response object if successful
    def self.request(method, url, options = {})
      max_retries = options[:max_retries] || 3
      retry_delay = options[:retry_delay] || 30
      attempts = 0

      request_options = build_request_options(method, options)
      response = Typhoeus::Request.new(url, request_options).run

      while retry_needed?(response) && attempts < max_retries
        attempts += 1
        Discord.log_warn(
          "HTTP #{response&.code || 'error'} for #{url}. Retry #{attempts}/" \
          "#{max_retries} in #{retry_delay}s"
        )
        sleep retry_delay
        response = Typhoeus::Request.new(url, request_options).run
      end

      response
    rescue StandardError => e
      Discord.log_warn("HTTP error when requesting URL '#{url}': #{e.message}")
      nil
    end

    # Determines if a retry is needed based on response status
    # @param response [Typhoeus::Response, nil] The HTTP response
    # @return [Boolean] True if retry is needed
    def self.retry_needed?(response)
      return true if response.nil? || [0, 400].include?(response.code) || response.code.between?(500, 599)

      false
    end

    # Performs an HTTP GET request
    # @param url [String] The URL to request
    # @param options [Hash] Request options including headers
    # @return [Typhoeus::Response, nil] Response object if successful
    def self.get(url, options = {})
      request(:get, url, options)
    end

    # Performs an HTTP POST request
    # @param url [String] The URL to request
    # @param options [Hash] Request options including body and headers
    # @return [Typhoeus::Response, nil] Response object if successful
    def self.post(url, options = {})
      request(:post, url, options)
    end
  end
end
