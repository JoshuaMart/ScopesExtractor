# frozen_string_literal: true

require 'rotp'

module ScopesExtractor
  module Platforms
    module YesWeHack
      class Authenticator
        BASE_URL = 'https://api.yeswehack.com'

        def initialize(email:, password:, otp_secret:, client: nil)
          @email = email
          @password = password
          @otp_secret = otp_secret
          @client = client || HttpClient.new
        end

        def authenticate
          ScopesExtractor.logger.debug "Starting YesWeHack authentication for #{@email}"

          # Step 1: Initial Login
          initial_token = login

          # Step 2: TOTP Challenge
          final_token = otp_challenge(initial_token)

          ScopesExtractor.logger.debug 'YesWeHack authentication successful'
          final_token
        end

        private

        def login
          response = @client.post("#{BASE_URL}/login") do |req|
            req.headers['Content-Type'] = 'application/json'
            req.body = { email: @email, password: @password }.to_json
          end

          raise Error, "YesWeHack login failed: #{response.status} - #{response.body}" unless response.status == 200

          data = JSON.parse(response.body)
          data['totp_token'] || data['token']
        end

        def otp_challenge(session_token)
          otp_code = ROTP::TOTP.new(@otp_secret).now

          response = @client.post("#{BASE_URL}/account/totp") do |req|
            req.headers['Content-Type'] = 'application/json'
            req.body = { token: session_token, code: otp_code }.to_json
          end

          unless response.status == 200
            raise Error, "YesWeHack TOTP challenge failed: #{response.status} - #{response.body}"
          end

          JSON.parse(response.body)['token']
        end
      end
    end
  end
end
