# frozen_string_literal: true

module ScopesExtractor
  module Hackerone
    # Hackerone Sync Scopes
    module Scopes
      CATEGORIES = {
        url: %w[URL WILDCARD IP_ADDRESS API],
        cidr: %w[CIDR],
        mobile: %w[GOOGLE_PLAY_APP_ID OTHER_APK APPLE_STORE_APP_ID TESTFLIGHT OTHER_IPA],
        other: %w[OTHER],
        executable: %w[DOWNLOADABLE_EXECUTABLES WINDOWS_APP_STORE_APP_ID],
        hardware: %w[HARDWARE],
        ai: %w[AI_MODEL],
        code: %w[SOURCE_CODE SMART_CONTRACT]
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
          endpoint = if category == :url
                       normalize(attributes['asset_identifier'])
                     else
                       attributes['asset_identifier']
                     end
          next unless endpoint

          scopes[category] << endpoint
        end

        scopes
      end

      def self.find_category(infos)
        category = CATEGORIES.find { |_key, values| values.include?(infos['asset_type']) }&.first
        Utilities.log_warn("Hackerone - Inexistent categories : #{infos['asset_type']}") if category.nil?

        category
      end

      def self.normalize(endpoint)
        endpoint = endpoint[..-2] if endpoint.end_with?('/*')
        endpoint = endpoint[..-2] if endpoint.start_with?('*') && endpoint.end_with?('/')
        endpoint.sub!(%r{https?://}, '') if endpoint.match?(%r{https?://\*\.})

        scope = if !endpoint.start_with?('*.') && endpoint.include?('*.')
                  match = endpoint.match(/(?<wildcard>\*\.[\w.-]+\.\w+)/)
                  return unless match

                  match[:wildcard]
                else
                  endpoint
                end

        invalid_chars = [',', '{', '<', '[', '(', ' ']
        if invalid_chars.any? { |char| scope.include?(char) } || !scope.include?('.')
          Utilities.log_warn("Hackerone - Non-normalized scope : #{scope}")
          return
        end

        scope.strip
      end
    end
  end
end
