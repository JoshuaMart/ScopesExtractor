# frozen_string_literal: true

module ScopesExtractor
  module Platforms
    module YesWeHack
      # YesWeHack platform implementation
      class Platform < BasePlatform
        BASE_URL = 'https://api.yeswehack.com'

        def initialize(config = {})
          super
          @authenticator = nil
          @token = nil
        end

        # Returns the platform name
        # @return [String] platform name
        def name
          'YesWeHack'
        end

        # Validates access by attempting authentication
        # @return [Boolean] true if authentication succeeds, false otherwise
        def valid_access?
          authenticate
          true
        rescue StandardError => e
          ScopesExtractor.logger.error "[YesWeHack] Access validation failed: #{e.message}"
          false
        end

        # Fetches all programs from YesWeHack
        # @return [Array<Models::Program>] array of programs
        def fetch_programs
          authenticate unless authenticated?

          # TODO: Implement in next step with ProgramFetcher
          []
        end

        private

        def authenticate
          return @token if @token

          @authenticator ||= Authenticator.new(
            email: @config[:email],
            password: @config[:password],
            otp_secret: @config[:otp]
          )

          @token = @authenticator.authenticate
        end

        def authenticated?
          !@token.nil?
        end
      end
    end
  end
end
