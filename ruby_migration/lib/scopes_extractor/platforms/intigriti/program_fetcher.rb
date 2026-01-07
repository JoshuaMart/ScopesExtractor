# frozen_string_literal: true

module ScopesExtractor
  module Platforms
    module Intigriti
      class ProgramFetcher
        BASE_URL = 'https://api.intigriti.com/external/researcher/v1'

        def initialize(client)
          @client = client
        end

        def fetch_all
          programs = []
          offset = 0
          limit = 100

          loop do
            ScopesExtractor.logger.debug "[Intigriti] Fetching programs with offset #{offset}"
            resp = @client.get("#{BASE_URL}/programs", { offset: offset, limit: limit })

            unless resp.status == 200
              ScopesExtractor.logger.error "[Intigriti] Failed to fetch programs: #{resp.status}"
              break
            end

            data = JSON.parse(resp.body)
            items = data['items'] || []
            break if items.empty?

            programs.concat(items)
            break if items.size < limit

            offset += limit
          end

          programs
        end

        def fetch_details(program_id)
          resp = @client.get("#{BASE_URL}/programs/#{program_id}")
          return nil unless resp.status == 200

          JSON.parse(resp.body)
        end
      end
    end
  end
end
