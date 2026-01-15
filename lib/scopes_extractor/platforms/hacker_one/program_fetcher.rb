# frozen_string_literal: true

module ScopesExtractor
  module Platforms
    module HackerOne
      # HackerOne program fetcher
      class ProgramFetcher
        BASE_URL = 'https://api.hackerone.com/v1'

        def initialize(auth_header)
          @auth_header = auth_header
        end

        # Fetches all programs from HackerOne with pagination
        # @return [Array<Hash>] array of raw program data
        # @raise [StandardError] if fetching fails
        def fetch_all
          programs = []
          page = 1

          loop do
            ScopesExtractor.logger.debug "[HackerOne] Fetching programs page #{page}"

            url = "#{BASE_URL}/hackers/programs?page%5Bnumber%5D=#{page}&page%5Bsize%5D=100"
            response = HTTP.get(
              url,
              headers: { 'Authorization' => "Basic #{@auth_header}" }
            )

            raise "Failed to fetch programs page #{page}: HTTP #{response.code}" unless response.success?

            data = JSON.parse(response.body)
            items = data['data'] || []
            break if items.empty?

            programs.concat(items)

            ScopesExtractor.logger.debug "[HackerOne] Fetched #{items.size} programs from page #{page}"

            # Check if there's a next page
            break unless data.dig('links', 'next')

            page += 1
          end

          ScopesExtractor.logger.info "[HackerOne] Fetched total of #{programs.size} program(s)"
          programs
        end

        # Fetches scopes for a specific program
        # @param handle [String] program handle
        # @return [Array<Hash>] array of scope data
        # @raise [StandardError] if fetching fails
        def fetch_scopes(handle)
          scopes = []
          page = 1

          loop do
            url = "#{BASE_URL}/hackers/programs/#{handle}/structured_scopes?page%5Bnumber%5D=#{page}&page%5Bsize%5D=100"
            response = HTTP.get(
              url,
              headers: { 'Authorization' => "Basic #{@auth_header}" }
            )

            raise "Failed to fetch scopes for #{handle}: HTTP #{response.code}" unless response.success?

            data = JSON.parse(response.body)
            items = data['data'] || []
            break if items.empty?

            scopes.concat(items)

            # Check if there's a next page
            break unless data.dig('links', 'next')

            page += 1
          end

          scopes
        end
      end
    end
  end
end
