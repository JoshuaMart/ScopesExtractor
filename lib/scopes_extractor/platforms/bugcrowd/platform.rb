# frozen_string_literal: true

module ScopesExtractor
  module Platforms
    module Bugcrowd
      # Bugcrowd platform implementation
      class Platform < BasePlatform
        BASE_URL = 'https://bugcrowd.com'

        def initialize(config = {})
          super
          @email = config[:email]
          @password = config[:password]
          @otp_secret = config[:otp_secret]
          @authenticator = nil
          @authenticated = false
        end

        # Returns the platform name
        # @return [String] platform name
        def name
          'Bugcrowd'
        end

        # Validates access by testing authentication
        # Resets authentication state and forces re-authentication on each call
        # Clears cookies to ensure fresh authentication flow
        # Retries authentication up to 3 times on failure
        # @return [Boolean] true if authentication succeeds, false otherwise
        # rubocop:disable Metrics/MethodLength
        def valid_access?
          return false unless @email && @password && @otp_secret

          max_retries = 3
          attempt = 0

          while attempt < max_retries
            attempt += 1

            # Clear cookies to prevent stale session issues
            HTTP.clear_cookies

            # Reset authentication state to force fresh authentication
            @authenticator = nil
            @authenticated = false

            begin
              ScopesExtractor.logger.debug "[Bugcrowd] Authentication attempt #{attempt}/#{max_retries}"

              @authenticator = Authenticator.new(
                email: @email,
                password: @password,
                otp_secret: @otp_secret
              )

              if @authenticator.authenticate
                ScopesExtractor.logger.info "[Bugcrowd] Authentication successful on attempt #{attempt}"
                @authenticated = true
                return true
              else
                ScopesExtractor.logger.warn "[Bugcrowd] Authentication failed on attempt #{attempt}/#{max_retries}"
              end
            rescue StandardError => e
              error_msg = "Authentication error on attempt #{attempt}/#{max_retries}: #{e.message}"
              ScopesExtractor.logger.warn "[Bugcrowd] #{error_msg}"
            end

            # Wait before retry (except on last attempt)
            sleep(2) if attempt < max_retries
          end

          # All retries failed
          ScopesExtractor.logger.error "[Bugcrowd] Authentication failed after #{max_retries} attempts"
          @authenticated = false
          false
        end
        # rubocop:enable Metrics/MethodLength

        # Fetches all programs from Bugcrowd
        # @return [Array<Models::Program>] array of programs
        # @raise [StandardError] if authentication or fetching fails
        def fetch_programs
          # Authenticate first
          unless @authenticated
            success = authenticate
            raise 'Authentication failed, cannot fetch programs' unless success
          end

          fetcher = ProgramFetcher.new
          raw_programs = fetcher.fetch_all

          raw_programs.filter_map do |raw|
            brief_url = raw['briefUrl']
            slug = brief_url[1..] # Remove leading slash

            # Skip VDP programs if configured
            # Note: Bugcrowd engagements.json doesn't have clear bounty indicator,
            # but category=bug_bounty filter should handle this

            # Fetch scopes for this program
            raw_scopes = fetcher.fetch_scopes(brief_url)
            next if raw_scopes.empty?

            begin
              parse_program(raw, slug, raw_scopes)
            rescue StandardError => e
              ScopesExtractor.logger.error "[Bugcrowd] Failed to parse program #{slug}: #{e.message}"
              ScopesExtractor.logger.debug e.backtrace.join("\n")
              nil
            end
          end
        end

        private

        # Authenticates with Bugcrowd
        def authenticate
          @authenticator ||= Authenticator.new(
            email: @email,
            password: @password,
            otp_secret: @otp_secret
          )

          @authenticated = @authenticator.authenticate
        end

        def parse_program(raw, slug, raw_scopes)
          scopes = raw_scopes.flat_map do |target|
            parse_scope(target)
          end.compact

          Models::Program.new(
            slug: slug,
            platform: 'bugcrowd',
            name: raw['name'],
            bounty: true, # All programs from bug_bounty category
            scopes: scopes
          )
        end

        def parse_scope(target)
          category = target['category']
          name = target['name']

          return nil if name.nil? || name.empty?

          type = map_scope_type(category)

          # Normalize the target name for web types
          normalized_values = if type == 'web'
                                Normalizer.normalize('bugcrowd', name)
                              else
                                [name.downcase]
                              end

          # Return array of scopes (can be multiple after normalization)
          normalized_values.map do |value|
            Models::Scope.new(
              value: value,
              type: type,
              is_in_scope: true
            )
          end
        end

        def map_scope_type(category)
          # Map Bugcrowd categories to our standard types
          case category
          when 'website', 'api', 'ip_address', 'network' then 'web'
          when 'android', 'ios' then 'mobile'
          when 'application' then 'executable'
          when 'hardware' then 'hardware'
          when 'code' then 'source_code'
          else 'other'
          end
        end
      end
    end
  end
end
