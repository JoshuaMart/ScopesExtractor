# frozen_string_literal: true

require 'rotp'

module ScopesExtractor
  module Platforms
    module Bugcrowd
      class Authenticator
        IDENTITY_URL = 'https://identity.bugcrowd.com'
        DASHBOARD_URL = 'https://bugcrowd.com/dashboard'

        def initialize(email:, password:, otp_secret:, client:)
          @email = email
          @password = password
          @otp_secret = otp_secret
          @client = client
        end

        def authenticate
          ScopesExtractor.logger.debug 'Starting Bugcrowd manual authentication flow'

          # 1. Get login page
          url = "#{IDENTITY_URL}/login?user_hint=researcher&returnTo=/dashboard"
          resp = @client.get(url)
          csrf = extract_csrf(resp)

          raise Error, 'Failed to extract Bugcrowd CSRF token' if csrf.empty?

          ScopesExtractor.logger.debug "Bugcrowd CSRF Extracted: #{csrf[0..5]}..."

          # 2. Login POST (expects 422 for OTP)
          resp = @client.post("#{IDENTITY_URL}/login") do |req|
            req.headers['X-Csrf-Token'] = csrf
            req.headers['Origin'] = IDENTITY_URL
            req.headers['Referer'] = url
            req.body = {
              username: @email,
              password: @password,
              user_type: 'RESEARCHER'
            }
          end

          # Bugcrowd returns 422 with OTP requirement
          raise Error, "Bugcrowd login failed: #{resp.status} - #{resp.body[0..100]}" unless resp.status == 422

          # 3. OTP Challenge
          otp_code = ROTP::TOTP.new(@otp_secret).now
          resp = @client.post("#{IDENTITY_URL}/auth/otp-challenge") do |req|
            req.headers['X-Csrf-Token'] = csrf
            req.headers['Origin'] = IDENTITY_URL
            req.headers['Referer'] = "#{IDENTITY_URL}/login"
            req.body = {
              username: @email,
              password: @password,
              user_type: 'RESEARCHER',
              otp_code: otp_code
            }
          end

          raise Error, "Bugcrowd OTP challenge failed: #{resp.status} - #{resp.body}" unless resp.status == 200

          data = JSON.parse(resp.body)
          redirect_url = data['redirect_to']

          # 4. Final session set (Follow redirects manually)
          current_url = redirect_url
          loop do
            resp = @client.get(current_url)
            break unless [301, 302, 303, 307, 308].include?(resp.status)

            new_location = resp.headers['Location']
            # Handle relative redirects
            current_url = URI.join(current_url, new_location).to_s
            ScopesExtractor.logger.debug "Following redirect to: #{current_url}"
          end

          # 5. Verify authentication
          unless authenticated?(resp)
            # Try to hit dashboard directly
            resp = @client.get('https://bugcrowd.com/dashboard')
            unless authenticated?(resp)
              raise Error,
                    "Bugcrowd authentication verification failed (Title: #{extract_title(resp)})"
            end
          end

          ScopesExtractor.logger.debug 'Bugcrowd authentication successful'
          true
        end

        private

        def extract_csrf(response)
          headers = response.headers
          return '' unless headers['Set-Cookie']

          # Handle both Array and String (Faraday returns String with Net::HTTP)
          cookies = Array(headers['Set-Cookie'])

          cookies.each do |cookie_set|
            cookie_set.split(/, (?=[^;]+=[^;]+;)/).each do |cookie|
              if (match = cookie.match(/csrf-token=([^;]+)/))
                return match[1]
              end
            end
          end

          # Fallback to meta tags
          if response.body&.match(/meta name="csrf-token" content="([^"]+)"/)
            return response.body.match(/meta name="csrf-token" content="([^"]+)"/)[1]
          end

          ''
        end

        def authenticated?(response)
          response.body.include?('<title>Dashboard - Bugcrowd') ||
            response.headers['Location'] == '/dashboard'
        end

        def extract_title(response)
          response.body.match(%r{<title>(.*?)</title>}m)&.[](1)&.strip || 'No title'
        end
      end
    end
  end
end
