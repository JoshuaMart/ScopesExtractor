# frozen_string_literal: true

module ScopesExtractor
  module Hackerone
    # Hackerone Sync Scopes
    module Scopes
      CATEGORIES = {
        url: %w[URL WILDCARD IP_ADDRESS API],
        cidr: %w[CIDR],
        mobile: %w[GOOGLE_PLAY_APP_ID OTHER_APK APPLE_STORE_APP_ID TESTFLIGHT OTHER_IPA],
        other: %w[OTHER AWS_CLOUD_CONFIG],
        executable: %w[DOWNLOADABLE_EXECUTABLES WINDOWS_APP_STORE_APP_ID],
        hardware: %w[HARDWARE],
        ai: %w[AI_MODEL],
        source_code: %w[SOURCE_CODE SMART_CONTRACT]
      }.freeze

      PROGRAMS_ENDPOINT = 'https://api.hackerone.com/v1/hackers/programs'

      def self.sync(program, config)
        url = File.join(PROGRAMS_ENDPOINT, program[:slug])
        response = HttpClient.get(url, { headers: config[:headers] })
        return unless response&.status == 200

        json = Parser.json_parse(response.body)
        return unless json

        data = json.dig('relationships', 'structured_scopes', 'data')
        return unless data

        {
          'in' => parse_scopes(data),
          'out' => {} # TODO
        }
      end

      def self.parse_scopes(targets)
        scopes = {}

        targets.each do |target|
          attributes = target['attributes']
          next unless attributes['eligible_for_bounty'] && attributes['eligible_for_submission']

          category = find_category(attributes)
          next unless category

          scopes[category] ||= []
          add_scope_to_category(scopes, category, attributes)
        end

        scopes
      end

      # Adds a scope to the appropriate category, with normalization for URLs
      # @param scopes [Hash] Scopes hash to add to
      # @param category [Symbol] Category to add the scope to
      # @param infos [Hash] Scope information
      # @return [void]
      def self.add_scope_to_category(scopes, category, infos)
        if category == :url
          Normalizer.run('Hackerone', infos['asset_identifier'])&.each { |url| scopes[category] << url }
        else
          scopes[category] << infos['asset_identifier']
        end
      end

      # Finds the standardized category for a scope item
      # @param infos [Hash] Scope item information
      # @return [Symbol, nil] Standardized category or nil if not found
      def self.find_category(infos)
        category = CATEGORIES.find { |_key, values| values.include?(infos['asset_type']) }&.first
        Discord.log_warn("Hackerone - Unknown category: #{infos}") if category.nil?

        category = :source_code if source_code?(infos['asset_identifier'])

        category
      end

      # Determines if a scope is a source code repository
      # @param scope [String] Scope value
      # @return [Boolean] True if the scope is a GitHub repository
      def self.source_code?(scope)
        scope&.start_with?('https://github.com/')
      end
    end
  end
end
