# frozen_string_literal: true

require 'rotp'
require 'json'

module ScopesExtractor
  module Platforms
    module YesWeHack
      # Handles authentication for YesWeHack platform
      # Uses email/password + TOTP for 2FA
      class Authenticator
        BASE_URL = 'https://api.yeswehack.com'

        attr_reader :email, :token

        def initialize(email:, password:, otp_secret:)
          @email = email
          @password = password
          @otp_secret = otp_secret
          @token = nil
        end

        # Performs full authentication flow
        # @return [String] the authentication token
        # @raise [StandardError] if authentication fails
        def authenticate
          ScopesExtractor.logger.debug "[YesWeHack] Starting authentication for #{@email}"

          # Step 1: Initial login with email/password
          initial_token = perform_login

          # Step 2: TOTP challenge with OTP code
          final_token = perform_otp_challenge(initial_token)

          @token = final_token
          ScopesExtractor.logger.debug '[YesWeHack] Authentication successful'
          final_token
        end

        # Checks if currently authenticated
        # @return [Boolean] true if authenticated, false otherwise
        def authenticated?
          !@token.nil?
        end

        private

        def perform_login
          response = HTTP.post(
            "#{BASE_URL}/login",
            body: { email: @email, password: @password }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

          raise "Login failed: #{response.code} - #{response.body}" unless response.success?

          data = JSON.parse(response.body)
          data['totp_token'] || data['token']
        end

        def perform_otp_challenge(session_token)
          otp_code = generate_otp_code

          response = HTTP.post(
            "#{BASE_URL}/account/totp",
            body: { token: session_token, code: otp_code }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

          raise "TOTP challenge failed: #{response.code} - #{response.body}" unless response.success?

          data = JSON.parse(response.body)
          data['token']
        end

        def generate_otp_code
          ROTP::TOTP.new(@otp_secret).now
        end
      end
    end
  end
end
