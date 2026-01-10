# frozen_string_literal: true

module ScopesExtractor
  module Platforms
    module Intigriti
      # Intigriti platform implementation
      class Platform < BasePlatform
        BASE_URL = 'https://api.intigriti.com/external/researcher/v1'

        def initialize(config = {})
          super
          @token = config[:token]
        end

        # Returns the platform name
        # @return [String] platform name
        def name
          'Intigriti'
        end

        # Validates access by testing the API token
        # @return [Boolean] true if token is valid, false otherwise
        def valid_access?
          return false unless @token

          # Test token with a simple API call
          response = HTTP.get(
            "#{BASE_URL}/programs?limit=1",
            headers: { 'Authorization' => "Bearer #{@token}" }
          )

          if response.success?
            ScopesExtractor.logger.debug '[Intigriti] Access validation successful'
            true
          else
            ScopesExtractor.logger.error "[Intigriti] Access validation failed: #{response.code}"
            false
          end
        rescue StandardError => e
          ScopesExtractor.logger.error "[Intigriti] Access validation error: #{e.message}"
          false
        end

        # Fetches all programs from Intigriti
        # @return [Array<Models::Program>] array of programs
        def fetch_programs
          fetcher = ProgramFetcher.new(@token)
          raw_programs = fetcher.fetch_all

          raw_programs.filter_map do |raw|
            # Skip VDP programs if configured (maxBounty == 0)
            if Config.skip_vdp?('intigriti') && raw.dig('maxBounty', 'value')&.zero?
              ScopesExtractor.logger.debug "[Intigriti] Skipping VDP program: #{raw['handle']}"
              next
            end

            # Fetch full details to get scopes
            details = fetcher.fetch_details(raw['id'])
            next unless details

            begin
              parse_program(raw, details)
            rescue StandardError => e
              ScopesExtractor.logger.error "[Intigriti] Failed to parse program #{raw['handle']}: #{e.message}"
              ScopesExtractor.logger.debug e.backtrace.join("\n")
              nil
            end
          end
        end

        private

        def parse_program(raw, details)
          # Intigriti uses "domains" -> "content" for scopes list
          scopes_data = details.dig('domains', 'content')
          return nil unless scopes_data

          scopes = scopes_data.flat_map do |raw_scope|
            parse_scope(raw_scope) || []
          end

          Models::Program.new(
            slug: raw['handle'],
            platform: 'intigriti',
            name: raw['name'],
            bounty: raw.dig('maxBounty', 'value')&.positive? || false,
            scopes: scopes
          )
        end

        def parse_scope(raw_scope)
          # Skip if tier is "No Bounty"
          return nil if raw_scope.dig('tier', 'value') == 'No Bounty'

          endpoint = raw_scope['endpoint']
          return nil if endpoint.nil? || endpoint.empty?

          type_id = raw_scope.dig('type', 'id')
          type = map_scope_type(type_id)

          # Determine if in scope or out of scope
          is_in_scope = raw_scope.dig('tier', 'value') != 'Out Of Scope'

          # Normalize the endpoint value for web types
          normalized_values = if type == 'web' && is_in_scope
                                Normalizer.normalize('intigriti', endpoint)
                              else
                                [endpoint.downcase]
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

        def map_scope_type(type_id)
          # Map Intigriti type IDs to our standard types
          case type_id
          when 1, 7 then 'web'
          when 2, 3 then 'mobile'
          when 4 then 'cidr'
          when 8 then 'source_code'
          else 'other' # device (5), other (6), unknown
          end
        end
      end
    end
  end
end
