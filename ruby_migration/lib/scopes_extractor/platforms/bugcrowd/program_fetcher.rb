# frozen_string_literal: true

module ScopesExtractor
  module Platforms
    module Bugcrowd
      class ProgramFetcher
        def initialize(client)
          @client = client
        end

        def fetch_all
          programs = []
          page = 1

          loop do
            ScopesExtractor.logger.debug "[Bugcrowd] Fetching engagements page #{page}"
            resp = @client.get("https://bugcrowd.com/engagements.json?page=#{page}&category=bug_bounty")

            unless resp.status == 200
              ScopesExtractor.logger.error "[Bugcrowd] Failed to fetch engagements: #{resp.status}"
              break
            end

            data = JSON.parse(resp.body)
            items = data['engagements'] || []
            break if items.empty?

            # Only open programs
            programs.concat(items.select { |i| i['accessStatus'] == 'open' })

            page += 1
          end

          programs
        end

        def fetch_scopes(brief_url)
          # brief_url is "/program-name" or "/engagements/program-name"
          if brief_url.start_with?('/engagements/')
            fetch_engagement_scopes(brief_url)
          else
            fetch_group_scopes(brief_url)
          end
        rescue StandardError => e
          ScopesExtractor.logger.error "[Bugcrowd] Error fetching scopes for #{brief_url}: #{e.message}"
          []
        end

        private

        def fetch_engagement_scopes(brief_url)
          # Need to find the changelog ID in the HTML page (as done in the original code)
          resp = @client.get("https://bugcrowd.com#{brief_url}")
          match = resp.body.match(%r{changelog/(?<changelog>[-a-f0-9]+)})
          return [] unless match

          changelog_id = match[:changelog]
          resp = @client.get("https://bugcrowd.com#{brief_url}/changelog/#{changelog_id}.json")
          return [] unless resp.status == 200

          data = JSON.parse(resp.body)
          raw_scopes = data.dig('data', 'scope') || []

          # Flatten targets from groups
          raw_scopes.flat_map do |s|
            # Skip out-of-scope markers in name
            next [] if ['oos', 'out of scope'].any? { |m| s['name'].downcase.include?(m) }

            s['targets'] || []
          end.compact
        end

        def fetch_group_scopes(brief_url)
          # Use /target_groups API
          resp = @client.get("https://bugcrowd.com#{brief_url}/target_groups", {}, { 'Accept' => 'application/json' })
          return [] unless resp.status == 200

          data = JSON.parse(resp.body)
          groups = data['groups'] || []

          groups.flat_map do |g|
            next [] unless g['in_scope']

            # Fetch targets for each group
            t_resp = @client.get("https://bugcrowd.com#{g['targets_url']}", {}, { 'Accept' => 'application/json' })
            next [] unless t_resp.status == 200

            JSON.parse(t_resp.body)['targets'] || []
          end.compact
        end
      end
    end
  end
end
