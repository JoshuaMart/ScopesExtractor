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

          fetcher = ProgramFetcher.new(@token)
          raw_programs = fetcher.fetch_all

          raw_programs.filter_map do |raw|
            # Fetch full details to get scopes
            details = fetcher.fetch_details(raw['slug'])
            next unless details

            begin
              parse_program(details)
            rescue StandardError => e
              # Log the error and skip this program, but don't crash the whole sync
              ScopesExtractor.logger.error "[YesWeHack] Failed to parse program #{raw['slug']}: #{e.message}"
              ScopesExtractor.logger.debug e.backtrace.join("\n")
              nil
            end
          end
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

        def parse_program(data)
          # Parse in-scope assets
          in_scopes = (data['scopes'] || []).filter_map do |raw_scope|
            parse_scope(raw_scope, true)
          end

          # Parse out-of-scope assets - YesWeHack uses string array for out_of_scope
          out_scopes = (data['out_of_scope'] || []).filter_map do |raw_scope|
            # Skip string items (textual descriptions, not actual scopes)
            next if raw_scope.is_a?(String)

            parse_scope(raw_scope, false)
          end

          Models::Program.new(
            slug: data['slug'],
            platform: 'yeswehack',
            name: data['title'],
            bounty: data['bounty'] == true,
            scopes: in_scopes + out_scopes
          )
        end

        def parse_scope(raw_scope, is_in_scope)
          type = map_scope_type(raw_scope['scope_type'])
          value = raw_scope['scope']

          # Return scope without normalization (DiffEngine will handle it)
          Models::Scope.new(
            value: value,
            type: type,
            is_in_scope: is_in_scope
          )
        end

        def map_scope_type(ywh_type)
          case ywh_type
          when 'web-application', 'api', 'ip-address', 'wildcard' then 'web'
          when 'mobile-application', 'mobile-application-android', 'mobile-application-ios' then 'mobile'
          when 'open-source' then 'source_code'
          when 'application' then 'executable'
          else 'other'
          end
        end
      end
    end
  end
end
