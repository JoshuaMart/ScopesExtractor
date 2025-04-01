# frozen_string_literal: true

module ScopesExtractor
  # Bugcrowd platform authentication utilities
  module Bugcrowd
    LOGIN_URL = 'https://identity.bugcrowd.com/login'
    DASHBOARD_URL = '/dashboard'

    # Authenticates with Bugcrowd
    # @param config [Hash] Configuration containing email and password
    # @return [Boolean] True if authentication is successful, false otherwise
    def self.authenticate(config)
      url = "#{LOGIN_URL}?user_hint=researcher&returnTo=#{DASHBOARD_URL}"
      resp = HttpClient.get(url)
      return false unless valid_response?(resp, 200)

      csrf = extract_csrf(resp)
      return false unless csrf

      redirect_to = login(config, csrf)
      return false unless redirect_to

      check_authentication_success(redirect_to)
    end

    # Handles login request
    # @param config [Hash] Configuration containing email and password
    # @param csrf [String] CSRF token
    # @return [String, nil] Redirect URL if login successful, nil otherwise
    def self.login(config, csrf)
      options = {
        headers: { 'X-Csrf-Token' => csrf, 'Origin' => 'https://identity.bugcrowd.com' },
        body: prepare_body(config)
      }

      resp = HttpClient.post(LOGIN_URL, options)
      return nil unless valid_response?(resp, 200)

      body = Parser.json_parse(resp.body)
      body['redirect_to']
    end

    # Prepares request body for login
    # @param config [Hash] Configuration containing email and password
    # @return [String] Encoded request body
    def self.prepare_body(config)
      "username=#{CGI.escape(config[:email])}&password=#{CGI.escape(config[:password])}&user_type=RESEARCHER"
    end

    # Extracts CSRF token from response headers
    # @param resp [HTTP::Response] HTTP response object
    # @return [String, nil] CSRF token if found, nil otherwise
    def self.extract_csrf(resp)
      # Vérifier si les headers et set-cookie existent avant d'appeler match
      headers = resp&.headers
      return nil unless headers

      cookies = headers['set-cookie']
      return nil unless cookies

      match = cookies.match(%r{csrf-token=(?<csrf>[\w+/]+)})
      match ? match[:csrf] : nil
    end

    # Follows HTTP redirects until reaching dashboard or a non-redirect status
    # @param response [HTTP::Response] Initial HTTP response
    # @param expected_statuses [Array<Integer>] List of status codes to consider as redirects
    # @return [HTTP::Response, nil] Final response or nil if redirection failed
    def self.follow_redirects(response, *expected_statuses)
      current_response = response

      while expected_statuses.include?(current_response&.status)
        location = current_response&.headers&.[]('location')
        return nil unless location
        return current_response if location == DASHBOARD_URL

        current_response = HttpClient.get(location)
      end

      current_response
    end

    # Checks if authentication was successful by following redirects
    # @param redirect_to [String] URL to redirect to after login
    # @return [Boolean] True if authenticated successfully, false otherwise
    def self.check_authentication_success(redirect_to)
      resp = follow_redirects(HttpClient.get(redirect_to), 302, 303, 307)
      return false unless resp

      location = resp&.headers&.[]('location')
      resp&.body&.include?('<title>Dashboard - Bugcrowd') || location == DASHBOARD_URL
    end

    # Validates HTTP response
    # @param resp [HTTP::Response] HTTP response to validate
    # @param expected_status [Integer] Expected HTTP status code
    # @return [Boolean] True if response is valid, false otherwise
    def self.valid_response?(resp, expected_status)
      !resp.nil? && resp.status == expected_status
    end
  end
end
