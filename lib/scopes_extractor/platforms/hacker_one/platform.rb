# frozen_string_literal: true

require 'base64'

module ScopesExtractor
  module Platforms
    module HackerOne
      # HackerOne platform implementation
      class Platform < BasePlatform
        BASE_URL = 'https://api.hackerone.com/v1'

        def initialize(config = {})
          super
          @username = config[:username]
          @api_token = config[:api_token]
        end

        # Returns the platform name
        # @return [String] platform name
        def name
          'HackerOne'
        end

        # Validates access by testing the API credentials with Basic Auth
        # @return [Boolean] true if credentials are valid, false otherwise
        def valid_access?
          return false unless @username && @api_token

          # Test credentials with a simple API call
          auth = Base64.strict_encode64("#{@username}:#{@api_token}")
          response = HTTP.get(
            "#{BASE_URL}/hackers/programs?page[size]=1",
            headers: { 'Authorization' => "Basic #{auth}" }
          )

          if response.success?
            ScopesExtractor.logger.debug '[HackerOne] Access validation successful'
            true
          else
            ScopesExtractor.logger.error "[HackerOne] Access validation failed: #{response.code}"
            false
          end
        rescue StandardError => e
          ScopesExtractor.logger.error "[HackerOne] Access validation error: #{e.message}"
          false
        end

        # Fetches all programs from HackerOne
        # @return [Array<Models::Program>] array of programs
        def fetch_programs
          # Create Basic Auth header
          auth = Base64.strict_encode64("#{@username}:#{@api_token}")
          fetcher = ProgramFetcher.new(auth)
          raw_programs = fetcher.fetch_all

          # Filter out VDP programs before fetching details
          if Config.skip_vdp?('hackerone')
            raw_programs = raw_programs.reject do |raw|
              attr = raw['attributes']
              if attr['offers_bounties'] == false
                ScopesExtractor.logger.debug "[HackerOne] Skipping VDP program: #{attr['handle']}"
                true
              else
                false
              end
            end
          end

          raw_programs.filter_map do |raw|
            attr = raw['attributes']

            # Only process open programs
            next unless attr['submission_state'] == 'open'

            handle = attr['handle']

            begin
              # Fetch scopes for this program
              scopes_data = fetcher.fetch_scopes(handle)
              parse_program(raw, scopes_data)
            rescue StandardError => e
              ScopesExtractor.logger.error "[HackerOne] Failed to fetch/parse program #{handle}: #{e.message}"
              ScopesExtractor.logger.debug e.backtrace.join("\n")
              nil
            end
          end
        end

        private

        def parse_program(raw, scopes_data)
          attr = raw['attributes']

          scopes = scopes_data.flat_map do |raw_scope|
            parse_scope(raw_scope)
          end.compact

          Models::Program.new(
            slug: attr['handle'],
            platform: 'hackerone',
            name: attr['name'],
            bounty: attr['offers_bounties'] == true,
            scopes: scopes
          )
        end

        def parse_scope(raw_scope)
          s_attr = raw_scope['attributes']

          # Skip if not eligible for submission (out of scope)
          return nil if s_attr['eligible_for_submission'] == false

          asset_identifier = s_attr['asset_identifier']
          return nil if asset_identifier.nil? || asset_identifier.empty?

          asset_type = s_attr['asset_type']
          type = map_scope_type(asset_type)

          # Determine if in scope (eligible for bounty and submission)
          is_in_scope = s_attr['eligible_for_bounty'] == true && s_attr['eligible_for_submission'] == true

          # Normalize the asset identifier for web types
          normalized_values = if type == 'web' && is_in_scope
                                Normalizer.normalize('hackerone', asset_identifier)
                              else
                                [asset_identifier.downcase]
                              end

          # Return array of scopes (can be multiple after normalization)
          normalized_values.map do |value|
            Models::Scope.new(
              value: value,
              type: type,
              is_in_scope: is_in_scope
            )
          end
        end

        def map_scope_type(asset_type)
          # Map HackerOne asset types to our standard types
          case asset_type
          when 'URL', 'WILDCARD', 'IP_ADDRESS', 'API' then 'web'
          when 'CIDR' then 'cidr'
          when 'GOOGLE_PLAY_APP_ID', 'OTHER_APK', 'APPLE_STORE_APP_ID', 'TESTFLIGHT', 'OTHER_IPA' then 'mobile'
          when 'SOURCE_CODE', 'SMART_CONTRACT' then 'source_code'
          when 'DOWNLOADABLE_EXECUTABLES', 'WINDOWS_APP_STORE_APP_ID' then 'executable'
          when 'HARDWARE' then 'hardware'
          else 'other' # AI_MODEL and unknown types
          end
        end
      end
    end
  end
end
