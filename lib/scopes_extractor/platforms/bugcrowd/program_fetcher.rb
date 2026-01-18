# frozen_string_literal: true

module ScopesExtractor
  module Platforms
    module Bugcrowd
      # Bugcrowd program fetcher
      class ProgramFetcher
        BASE_URL = 'https://bugcrowd.com'

        def initialize
          # No auth needed, cookies are handled by HTTP module
        end

        # Fetches all programs from Bugcrowd for a given category
        # @param category [String] program category ('bug_bounty' or 'vdp')
        # @return [Array<Hash>] array of raw program data
        # @raise [StandardError] if fetching fails
        def fetch_all(category: 'bug_bounty')
          programs = []
          page = 1

          loop do
            ScopesExtractor.logger.debug "[Bugcrowd] Fetching #{category} engagements page #{page}"

            url = "#{BASE_URL}/engagements.json?page=#{page}&category=#{category}"
            response = HTTP.get(url)

            raise "Failed to fetch engagements page #{page}: HTTP #{response.code}" unless response.success?

            data = JSON.parse(response.body)
            items = data['engagements'] || []
            break if items.empty?

            # Only keep open programs
            open_programs = items.select { |item| item['accessStatus'] == 'open' }
            programs.concat(open_programs)

            ScopesExtractor.logger.debug "[Bugcrowd] Fetched #{open_programs.size} open programs from page #{page}"

            page += 1
          end

          ScopesExtractor.logger.info "[Bugcrowd] Fetched total of #{programs.size} program(s)"
          programs
        end

        # Fetches scopes for a specific program
        # @param brief_url [String] program brief URL (e.g., "/program-name" or "/engagements/program-name")
        # @return [Array<Hash>] array of scope targets
        # @raise [StandardError] if fetching fails
        def fetch_scopes(brief_url)
          if brief_url.start_with?('/engagements/')
            fetch_engagement_scopes(brief_url)
          else
            fetch_group_scopes(brief_url)
          end
        end

        private

        # Fetches scopes for engagement-type programs
        # @param brief_url [String] engagement URL
        # @return [Array<Hash>] array of targets
        def fetch_engagement_scopes(brief_url)
          # Step 1: Fetch HTML page to extract changelog ID
          response = HTTP.get("#{BASE_URL}#{brief_url}")

          unless response.success?
            ScopesExtractor.logger.debug "[Bugcrowd] Failed to fetch engagement page: #{brief_url}"
            return []
          end

          # Extract changelog ID from HTML
          match = response.body.match(%r{changelog/(?<changelog>[-a-f0-9]+)})
          unless match
            ScopesExtractor.logger.debug "[Bugcrowd] Failed to extract changelog ID from: #{brief_url}"
            return []
          end

          changelog_id = match[:changelog]

          # Step 2: Fetch changelog JSON
          changelog_url = "#{BASE_URL}#{brief_url}/changelog/#{changelog_id}.json"
          response = HTTP.get(changelog_url)

          unless response.success?
            ScopesExtractor.logger.debug "[Bugcrowd] Failed to fetch changelog: #{changelog_url}"
            return []
          end

          data = JSON.parse(response.body)
          raw_scopes = data.dig('data', 'scope') || []

          # Step 3: Flatten targets from scope groups
          raw_scopes.flat_map do |scope_group|
            # Skip out-of-scope markers
            next [] if out_of_scope?(scope_group['name'])

            scope_group['targets'] || []
          end.compact
        end

        # Fetches scopes for group-type programs
        # @param brief_url [String] program URL
        # @return [Array<Hash>] array of targets
        def fetch_group_scopes(brief_url)
          # Step 1: Fetch target groups
          groups_url = "#{BASE_URL}#{brief_url}/target_groups"
          response = HTTP.get(
            groups_url,
            headers: { 'Accept' => 'application/json' }
          )

          unless response.success?
            ScopesExtractor.logger.debug "[Bugcrowd] Failed to fetch target groups: #{groups_url}"
            return []
          end

          data = JSON.parse(response.body)
          groups = data['groups'] || []

          # Step 2: Fetch targets for each in-scope group
          groups.flat_map do |group|
            next [] unless group['in_scope']

            targets_url = "#{BASE_URL}#{group['targets_url']}"
            response = HTTP.get(
              targets_url,
              headers: { 'Accept' => 'application/json' }
            )

            next [] unless response.success?

            target_data = JSON.parse(response.body)
            target_data['targets'] || []
          end.compact
        end

        # Checks if a scope name indicates out-of-scope
        # @param name [String] scope name
        # @return [Boolean] true if out of scope
        def out_of_scope?(name)
          return false unless name

          downcased = name.downcase
          ['oos', 'out of scope'].any? { |marker| downcased.include?(marker) }
        end
      end
    end
  end
end
