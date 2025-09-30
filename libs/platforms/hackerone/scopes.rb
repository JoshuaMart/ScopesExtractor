# frozen_string_literal: true

module ScopesExtractor
  module Hackerone
    # Hackerone Sync Scopes
    module Scopes
      CATEGORIES = {
        web: %w[URL WILDCARD IP_ADDRESS API],
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
        all_scopes = fetch_all_scopes(program, config)
        return unless all_scopes

        {
          'in' => parse_scopes(all_scopes),
          'out' => {} # TODO
        }
      end

      def self.fetch_all_scopes(program, config)
        all_scopes = []
        page_number = 1

        loop do
          page_data = fetch_scopes_page(program, config, page_number)
          return nil unless page_data

          all_scopes.concat(page_data[:scopes])
          break unless page_data[:has_next]

          page_number += 1
        end

        all_scopes
      end

      def self.fetch_scopes_page(program, config, page_number)
        url = build_scopes_url(program[:slug], page_number)
        response = HttpClient.get(url, { headers: config[:headers] })

        unless response&.code == 200
          Discord.log_warn("Hackerone - Unable to fetch scopes page #{page_number} for program #{program[:slug]}")
          return nil
        end

        json = Parser.json_parse(response.body)
        return nil unless json&.dig('data')

        {
          scopes: json['data'],
          has_next: json.dig('links', 'next')
        }
      end

      def self.build_scopes_url(slug, page_number)
        File.join(PROGRAMS_ENDPOINT, slug,
                  "structured_scopes?page[size]=100&page[number]=#{page_number}")
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

      # Adds a scope to the appropriate category, with normalization for web scopes
      # @param scopes [Hash] Scopes hash to add to
      # @param category [Symbol] Category to add the scope to
      # @param infos [Hash] Scope information
      # @return [void]
      def self.add_scope_to_category(scopes, category, infos)
        if category == :web
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

        ScopeCategoryDetector.adjust_category(category, infos['asset_identifier'])
      end
    end
  end
end
