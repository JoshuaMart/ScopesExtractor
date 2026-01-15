# frozen_string_literal: true

require 'json'

module ScopesExtractor
  module Platforms
    module YesWeHack
      # Fetches programs and their details from YesWeHack API
      class ProgramFetcher
        BASE_URL = 'https://api.yeswehack.com'

        def initialize(token)
          @token = token
        end

        # Fetches all programs with pagination
        # @return [Array<Hash>] array of program data from API
        # @raise [StandardError] if fetching fails
        def fetch_all
          programs = []
          page = 1

          loop do
            ScopesExtractor.logger.debug "[YesWeHack] Fetching programs page #{page}"

            response = HTTP.get(
              "#{BASE_URL}/programs?page=#{page}",
              headers: { 'Authorization' => "Bearer #{@token}" }
            )

            raise "Failed to fetch programs: HTTP #{response.code}" unless response.success?

            data = JSON.parse(response.body)
            current_page_items = data['items'] || []
            break if current_page_items.empty?

            programs.concat(current_page_items)

            # Check pagination
            pagination = data['pagination']
            break if pagination && page >= pagination['nb_pages']

            page += 1
          end

          ScopesExtractor.logger.info "[YesWeHack] Fetched #{programs.size} programs"
          programs
        end

        # Fetches detailed information for a specific program
        # @param slug [String] the program slug
        # @return [Hash, nil] program details or nil if failed
        def fetch_details(slug)
          response = HTTP.get(
            "#{BASE_URL}/programs/#{slug}",
            headers: { 'Authorization' => "Bearer #{@token}" }
          )

          return nil unless response.success?

          JSON.parse(response.body)
        end
      end
    end
  end
end
