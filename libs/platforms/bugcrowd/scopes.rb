# frozen_string_literal: true

module ScopesExtractor
  module Bugcrowd
    # Bugcrowd module handles fetching and parsing scope information for Bugcrowd bug bounty programs
    module Scopes
      # Mapping of Bugcrowd scope types to standardized categories
      CATEGORIES = {
        web: %w[website api ip_address],
        mobile: %w[android ios],
        other: %w[other],
        executable: %w[application],
        hardware: %w[hardware],
        iot: %w[iot],
        network: %w[network],
        source_code: %w[code]
      }.freeze

      # Constants for URL construction
      BASE_URL = 'https://bugcrowd.com'
      OUT_OF_SCOPE_MARKERS = ['oos', 'out of scope'].freeze

      # Synchronizes scope information for a Bugcrowd program
      # @param program [Hash] Program information hash containing brief_url
      # @return [Hash] Hash of in-scope and out-of-scope items categorized
      def self.sync(program)
        targets = extract_targets(program['briefUrl'])
        return { 'in' => {}, 'out' => {} } unless targets

        {
          'in' => parse_scopes(targets),
          'out' => {} # TODO: Implement out-of-scope parsing when available
        }
      end

      # Parses scope data into categorized formats
      # @param targets [Array] Array of target data objects
      # @return [Hash] Categorized scope data
      def self.parse_scopes(targets)
        scopes = {}

        targets.each do |target|
          category = find_category(target)
          next unless category

          scopes[category] ||= []
          add_scope_to_category(scopes, category, target)
        end

        scopes
      end

      # Adds a scope to the appropriate category, with normalization for web scopes
      # @param scopes [Hash] Scopes hash to add to
      # @param category [Symbol] Category to add the scope to
      # @param target [Hash] Target information
      # @return [void]
      def self.add_scope_to_category(scopes, category, target)
        if category == :web
          Normalizer.run('Bugcrowd', target['name'])&.each { |url| scopes[category] << url }
        else
          scopes[category] << target['name']
        end
      end

      # Finds the standardized category for a target item
      # @param target [Hash] Target item information
      # @return [Symbol, nil] Standardized category or nil if not found
      def self.find_category(target)
        category = CATEGORIES.find { |_key, values| values.include?(target['category']) }&.first
        Utilities.log_warn("Bugcrowd - Unknown category: #{target}") if category.nil?

        ScopeCategoryDetector.adjust_category(category, target['name'])
      end

      # Extracts targets from Bugcrowd program brief URL
      # @param brief_url [String] Program brief URL
      # @return [Array, nil] Array of targets or nil if extraction fails
      def self.extract_targets(brief_url)
        url = File.join(BASE_URL, brief_url)

        if brief_url.start_with?('/engagements/')
          targets_from_engagements(url)
        else
          targets_from_groups(url)
        end
      end

      # Extracts targets from engagement-type programs
      # @param url [String] Program URL
      # @return [Array, nil] Array of targets or nil if extraction fails
      def self.targets_from_engagements(url)
        # Fetch and extract changelog ID
        changelog_id = fetch_changelog_id(url)
        return nil unless changelog_id

        # Fetch targets from changelog
        targets = fetch_targets_from_changelog(url, changelog_id)
        return nil unless targets

        # Process targets
        process_engagement_targets(targets)
      end

      # Fetches changelog ID from engagement page
      # @param url [String] Program URL
      # @return [String, nil] Changelog ID or nil if not found
      def self.fetch_changelog_id(url)
        response = fetch_with_logging(url, 'engagement page')
        return nil unless response

        match = response.body.match(%r{changelog/(?<changelog>[-a-f0-9]+)})
        unless match
          Discord.log_warn("Bugcrowd - Failed to extract changelog ID from: #{url}")
          return nil
        end

        match[:changelog]
      end

      # Fetches targets from changelog
      # @param url [String] Base program URL
      # @param changelog_id [String] Changelog ID
      # @return [Array, nil] Array of scope objects or nil if fetch fails
      def self.fetch_targets_from_changelog(url, changelog_id)
        changelog_url = File.join(url, 'changelog', "#{changelog_id}.json")
        response = fetch_with_logging(changelog_url, 'changelog')
        return nil unless response

        json = parse_json_with_logging(response.body, changelog_url)
        return nil unless json

        json.dig('data', 'scope')
      end

      # Processes targets from engagement scopes
      # @param scopes [Array] Array of scope objects
      # @return [Array] Array of flattened targets
      def self.process_engagement_targets(scopes)
        targets = []

        scopes.each do |scope|
          # Skip out-of-scope items
          next if OUT_OF_SCOPE_MARKERS.any? { |marker| scope['name'].downcase.include?(marker) }

          targets << scope['targets']
        end

        targets.flatten
      end

      # Extracts targets from group-type programs
      # @param url [String] Program URL
      # @return [Array, nil] Array of targets or nil if extraction fails
      def self.targets_from_groups(url)
        # Fetch target groups
        groups = fetch_target_groups(url)
        return nil unless groups

        # Process each group and collect targets
        targets = []
        groups.each do |group|
          # Skip out-of-scope groups
          next unless group['in_scope']

          # Fetch targets for this group
          group_targets = fetch_group_targets(group['targets_url'])
          targets << group_targets if group_targets
        end

        targets.flatten
      end

      # Fetches target groups
      # @param url [String] Program URL
      # @return [Array, nil] Array of group objects or nil if fetch fails
      def self.fetch_target_groups(url)
        groups_url = File.join(url, 'target_groups')
        headers = { 'Accept' => 'application/json' }
        response = HttpClient.get(groups_url, { headers: headers })

        unless valid_response?(response)
          Discord.log_warn("Bugcrowd - Failed to fetch target groups: #{groups_url}")
          return nil
        end

        json = parse_json_with_logging(response.body, groups_url)
        return nil unless json

        json['groups']
      end

      # Fetches targets for a specific group
      # @param targets_url [String] Targets URL from group data
      # @return [Array, nil] Array of targets or nil if fetch fails
      def self.fetch_group_targets(targets_url)
        full_targets_url = File.join(BASE_URL, targets_url)
        response = fetch_with_logging(full_targets_url, 'targets')
        return nil unless response

        json = parse_json_with_logging(response.body, full_targets_url)
        return nil unless json

        json['targets']
      end

      # Helper method for fetching with error logging
      # @param url [String] URL to fetch
      # @param resource_type [String] Description of what's being fetched for logging
      # @return [HTTP::Response, nil] Response object or nil if request failed
      def self.fetch_with_logging(url, resource_type)
        retries = 0
        max_retries = 2

        loop do
          response = HttpClient.get(url)
          return response if valid_response?(response)

          retries += 1
          if retries <= max_retries
            sleep 3 # Sleep for 3 seconds before retrying
          else
            Discord.log_warn("Bugcrowd - Failed to fetch #{resource_type}: #{url} after #{max_retries} retries")
            return nil
          end
        end
      end

      # Helper method for parsing JSON with error logging
      # @param body [String] Response body to parse
      # @param url [String] URL for logging
      # @return [Hash, nil] Parsed JSON or nil if parsing failed
      def self.parse_json_with_logging(body, url)
        json = Parser.json_parse(body)
        unless json
          Discord.log_warn("Bugcrowd - Failed to parse JSON from: #{url}")
          return nil
        end
        json
      end

      # Validates HTTP response
      # @param response [HTTP::Response] HTTP response to validate
      # @return [Boolean] True if response is valid, false otherwise
      def self.valid_response?(response)
        !response.nil? && response.code == 200
      end
    end
  end
end
