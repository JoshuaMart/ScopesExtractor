# frozen_string_literal: true

require 'json'

module ScopesExtractor
  module Platforms
    module Intigriti
      # Fetches programs and their details from Intigriti API
      class ProgramFetcher
        BASE_URL = 'https://api.intigriti.com/external/researcher/v1'

        def initialize(token)
          @token = token
        end

        # Fetches all programs with pagination
        # @return [Array<Hash>] array of program data from API
        # @raise [StandardError] if fetching fails
        def fetch_all
          programs = []
          offset = 0
          limit = 100

          loop do
            ScopesExtractor.logger.debug "[Intigriti] Fetching programs with offset #{offset}"

            response = HTTP.get(
              "#{BASE_URL}/programs?limit=#{limit}&offset=#{offset}&statusId=3",
              headers: { 'Authorization' => "Bearer #{@token}" }
            )

            raise "Failed to fetch programs: HTTP #{response.code}" unless response.success?

            data = JSON.parse(response.body)
            current_items = data['records'] || []
            break if current_items.empty?

            programs.concat(current_items)

            # Check if there are more pages
            total = data['maxCount'] || 0
            break if programs.size >= total

            offset += limit
          end

          ScopesExtractor.logger.info "[Intigriti] Fetched #{programs.size} programs"
          programs
        end

        # Fetches detailed information for a specific program
        # @param program_id [String] the program ID
        # @return [Hash, nil] program details or nil if failed
        def fetch_details(program_id)
          response = HTTP.get(
            "#{BASE_URL}/programs/#{program_id}",
            headers: { 'Authorization' => "Bearer #{@token}" }
          )

          unless response.success?
            # Log 403 errors as debug (programs not accepted)
            if response.code == 403
              ScopesExtractor.logger.debug "[Intigriti] Program #{program_id} not accessible (403 - not accepted)"
            else
              ScopesExtractor.logger.warn "[Intigriti] Failed to fetch program #{program_id}: #{response.code}"
            end
            return nil
          end

          JSON.parse(response.body)
        end
      end
    end
  end
end
