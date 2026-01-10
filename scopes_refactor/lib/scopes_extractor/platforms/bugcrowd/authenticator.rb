# frozen_string_literal: true

require 'rotp'
require 'cgi'

module ScopesExtractor
  module Platforms
    module Bugcrowd
      # Bugcrowd authenticator
      class Authenticator
        IDENTITY_URL = 'https://identity.bugcrowd.com'
        DASHBOARD_URL = 'https://bugcrowd.com/dashboard'

        def initialize(email:, password:, otp_secret:)
          @email = email
          @password = password
          @otp_secret = otp_secret
          @authenticated = false
        end

        # Returns authentication status
        # @return [Boolean] true if authenticated
        def authenticated?
          @authenticated
        end

        # Performs authentication flow with Bugcrowd
        # @return [Boolean] true if successful
        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
        def authenticate
          # Validate credentials
          unless @email && @password && @otp_secret
            ScopesExtractor.logger.error '[Bugcrowd] Missing credentials (email, password, or OTP secret)'
            return false
          end

          ScopesExtractor.logger.debug '[Bugcrowd] Starting authentication flow'

          # Step 1: Get login page and extract CSRF token
          login_url = "#{IDENTITY_URL}/login?user_hint=researcher&returnTo=/dashboard"
          response = HTTP.get(login_url)

          unless response.success?
            ScopesExtractor.logger.error "[Bugcrowd] Failed to fetch login page: #{response.code}"
            return false
          end

          csrf = extract_csrf(response)
          unless csrf
            ScopesExtractor.logger.error '[Bugcrowd] Failed to extract CSRF token'
            return false
          end

          ScopesExtractor.logger.debug "[Bugcrowd] CSRF token extracted: #{csrf[0..5]}..."

          # Step 2: Initial login POST (expects 422 for OTP challenge)
          login_body = prepare_login_body(with_otp: false)
          response = HTTP.post(
            "#{IDENTITY_URL}/login",
            body: login_body,
            headers: {
              'X-Csrf-Token' => csrf,
              'Origin' => IDENTITY_URL,
              'Referer' => login_url,
              'Content-Type' => 'application/x-www-form-urlencoded'
            }
          )

          unless response.code == 422
            ScopesExtractor.logger.error "[Bugcrowd] Login failed: #{response.code}"
            return false
          end

          ScopesExtractor.logger.debug '[Bugcrowd] OTP challenge triggered'

          # Step 3: OTP challenge
          otp_body = prepare_login_body(with_otp: true)
          response = HTTP.post(
            "#{IDENTITY_URL}/auth/otp-challenge",
            body: otp_body,
            headers: {
              'X-Csrf-Token' => csrf,
              'Origin' => IDENTITY_URL,
              'Referer' => "#{IDENTITY_URL}/login",
              'Content-Type' => 'application/x-www-form-urlencoded'
            }
          )

          unless response.success?
            ScopesExtractor.logger.error "[Bugcrowd] OTP challenge failed: #{response.code}"
            return false
          end

          data = JSON.parse(response.body)
          redirect_url = data['redirect_to']

          ScopesExtractor.logger.debug "[Bugcrowd] Following redirect to: #{redirect_url}"

          # Step 4: Follow redirects to establish session
          current_url = redirect_url
          max_redirects = 10
          redirect_count = 0

          loop do
            break if redirect_count >= max_redirects

            response = HTTP.get(current_url)
            break unless [301, 302, 303, 307, 308].include?(response.code)

            location = response.headers['Location']
            break unless location

            # Handle relative URLs
            current_url = if location.start_with?('http')
                            location
                          else
                            # Assume same domain
                            "https://bugcrowd.com#{location}"
                          end

            ScopesExtractor.logger.debug "[Bugcrowd] Redirect to: #{current_url}"
            redirect_count += 1
          end

          # Step 5: Verify authentication by checking dashboard
          response = HTTP.get(DASHBOARD_URL)

          if authenticated_response?(response)
            ScopesExtractor.logger.debug '[Bugcrowd] Authentication successful'
            @authenticated = true
            true
          else
            ScopesExtractor.logger.error '[Bugcrowd] Authentication verification failed'
            false
          end
        rescue StandardError => e
          ScopesExtractor.logger.error "[Bugcrowd] Authentication error: #{e.message}"
          false
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

        private

        def extract_csrf(response)
          set_cookie = response.headers['Set-Cookie']
          return nil unless set_cookie

          # set-cookie can be an array or string
          cookies = set_cookie.is_a?(Array) ? set_cookie : [set_cookie]

          cookies.each do |cookie_str|
            match = cookie_str.match(/csrf-token=([^;]+)/)
            return match[1] if match
          end

          nil
        end

        def prepare_login_body(with_otp:)
          body = "username=#{CGI.escape(@email)}&password=#{CGI.escape(@password)}&user_type=RESEARCHER"

          if with_otp
            otp_code = ROTP::TOTP.new(@otp_secret).now
            body += "&otp_code=#{otp_code}"
          end

          body
        end

        def authenticated_response?(response)
          response.body.include?('<title>Dashboard - Bugcrowd') ||
            response.headers['Location'] == '/dashboard'
        end
      end
    end
  end
end
