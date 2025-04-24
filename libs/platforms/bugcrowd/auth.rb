# frozen_string_literal: true

module ScopesExtractor
  # Bugcrowd platform authentication utilities
  module Bugcrowd
    BASE_URL = 'https://identity.bugcrowd.com'
    DASHBOARD_URL = '/dashboard'

    # Authenticates with Bugcrowd
    # @param config [Hash] Configuration containing email and password
    # @return [Boolean] True if authentication is successful, false otherwise
    def self.authenticate(config)
      url = "#{BASE_URL}/login?user_hint=researcher&returnTo=#{DASHBOARD_URL}"
      resp = HttpClient.get(url, { follow_location: true })
      return { error: login_error(resp) } unless valid_response?(resp, 200)
      return { success: true } if authenticated?(resp)

      csrf = extract_csrf(resp)
      return { error: "No Login CSRF - #{resp.code}" } unless csrf

      response = login(config, csrf)
      return response if response[:error]

      check_authentication_success(response[:redirect_to])
    end

    # Build error message for login page access request
    # @return [String]
    def self.login_error(resp)
      message = "Invalid base login response - #{resp.code}"
      message += "\n\nResponse Headers:```\n#{resp.headers}\n```"
      message
    end

    # Handles login request
    # @param config [Hash] Configuration containing email and password
    # @param csrf [String] CSRF token
    # @return [String, nil] Redirect URL if login successful, nil otherwise
    def self.login(config, csrf)
      options = prepare_request(config, csrf, false)
      resp = HttpClient.post("#{BASE_URL}/login", options)
      return { error: 'Invalid login or password' } unless valid_response?(resp, 422)

      options = prepare_request(config, csrf, true)
      resp = HttpClient.post("#{BASE_URL}/auth/otp-challenge", options)
      return { error: 'Invalid OTP code' } unless valid_response?(resp, 200)

      body = Parser.json_parse(resp.body)
      { redirect_to: body['redirect_to'] }
    end

    # Prepare request options for login
    # @param config [Hash] Configuration containing email and password
    # @param with_otp [Boolean] body request with or without otp_code
    # @return [Hash]
    def self.prepare_request(config, csrf, with_otp)
      {
        headers: { 'X-Csrf-Token' => csrf, 'Origin' => 'https://identity.bugcrowd.com' },
        body: prepare_body(config, with_otp)
      }
    end

    # Prepare request body for login
    # @param config [Hash] Configuration containing email and password
    # @param with_otp [Boolean] body request with or without otp_code
    # @return [String] Encoded request body
    def self.prepare_body(config, with_otp)
      body = "username=#{CGI.escape(config[:email])}&password=#{CGI.escape(config[:password])}&user_type=RESEARCHER"

      if with_otp
        otp_code = ROTP::TOTP.new(config[:otp]).now
        body += "&otp_code=#{otp_code}"
      end

      body
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

      match = nil
      cookies.each do |cookie|
        next if match

        match = cookie.match(%r{csrf-token=(?<csrf>[\w+/]+)})
      end

      match ? match[:csrf] : nil
    end

    # Checks if authentication was successful by following redirects
    # @param redirect_to [String] URL to redirect to after login
    # @return [Boolean] True if authenticated successfully, false otherwise
    def self.check_authentication_success(redirect_to)
      resp = HttpClient.get(redirect_to, { follow_location: true })
      return { error: 'Error during follow redirect flow' } unless resp

      success = is_authenticated?(resp)
      { success: success }
    end

    def self.authenticated?(resp)
      location = resp&.headers&.[]('location')
      resp&.body&.include?('<title>Dashboard - Bugcrowd') || location == DASHBOARD_URL
    end

    # Validates HTTP response
    # @param resp [HTTP::Response] HTTP response to validate
    # @param expected_status [Integer] Expected HTTP status code
    # @return [Boolean] True if response is valid, false otherwise
    def self.valid_response?(resp, expected_status)
      !resp.nil? && resp.code == expected_status
    end
  end
end
