# frozen_string_literal: true

module ScopesExtractor
  module Platforms
    module HackerOne
      class ProgramFetcher
        BASE_URL = 'https://api.hackerone.com/v1'

        def initialize(client)
          @client = client
        end

        def fetch_all
          programs = []
          page = 1

          loop do
            ScopesExtractor.logger.debug "[HackerOne] Fetching programs page #{page}"
            resp = @client.get("#{BASE_URL}/hackers/programs", { page: { number: page, size: 100 } })

            unless resp.status == 200
              ScopesExtractor.logger.error "[HackerOne] Failed to fetch programs: #{resp.status}"
              break
            end

            data = JSON.parse(resp.body)
            items = data['data'] || []
            break if items.empty?

            programs.concat(items)

            # Check links for next page
            break unless data.dig('links', 'next')

            page += 1
          end

          programs
        end

        def fetch_details(handle)
          resp = @client.get("#{BASE_URL}/hackers/programs/#{handle}")
          return nil unless resp.status == 200

          JSON.parse(resp.body)
        end

        def fetch_scopes(handle)
          scopes = []
          page = 1

          loop do
            resp = @client.get("#{BASE_URL}/hackers/programs/#{handle}/structured_scopes", {
                                 page: { number: page, size: 100 }
                               })

            unless resp.status == 200
              ScopesExtractor.logger.warn "[HackerOne] Failed to fetch scopes for #{handle}: #{resp.status}"
              break
            end

            json = JSON.parse(resp.body)
            data = json['data'] || []
            break if data.empty?

            scopes.concat(data)

            # Check for next page
            has_next = json.dig('links', 'next')
            break unless has_next

            page += 1
          end

          scopes
        end
      end
    end
  end
end
