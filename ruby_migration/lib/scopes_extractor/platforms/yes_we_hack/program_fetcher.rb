# frozen_string_literal: true

module ScopesExtractor
  module Platforms
    module YesWeHack
      class ProgramFetcher
        BASE_URL = 'https://api.yeswehack.com'

        def initialize(client, token)
          @client = client
          @token = token
        end

        def fetch_all
          programs = []
          page = 1

          loop do
            ScopesExtractor.logger.debug "[YesWeHack] Fetching programs page #{page}"
            resp = @client.get("#{BASE_URL}/programs?page=#{page}") do |req|
              req.headers['Authorization'] = "Bearer #{@token}"
            end

            unless resp.status == 200
              ScopesExtractor.logger.error "[YesWeHack] Failed to fetch programs: #{resp.status}"
              break
            end

            data = JSON.parse(resp.body)
            current_page_items = data['items'] || []
            break if current_page_items.empty?

            programs.concat(current_page_items)

            # Check pagination
            pagination = data['pagination']
            break if pagination && page >= pagination['nb_pages']

            page += 1
          end

          programs
        end

        def fetch_details(slug)
          resp = @client.get("#{BASE_URL}/programs/#{slug}") do |req|
            req.headers['Authorization'] = "Bearer #{@token}"
          end

          return nil unless resp.status == 200

          JSON.parse(resp.body)
        end
      end
    end
  end
end
