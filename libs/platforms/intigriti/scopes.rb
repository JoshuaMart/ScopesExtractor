# frozen_string_literal: true

module ScopesExtractor
  module Intigriti
    # Intigrit Sync Scopes
    module Scopes
      CATEGORIES = {
        web: [1, 7],
        mobile: [2, 3],
        cidr: [4],
        device: [5],
        other: [6]
      }.freeze

      PROGRAMS_ENDPOINT = 'https://api.intigriti.com/external/researcher/v1/programs'

      DENY = [
        '.ripe.net'
      ].freeze

      def self.sync(program, headers)
        scopes = { 'in' => {}, 'out' => {} }

        response = HttpClient.get("#{PROGRAMS_ENDPOINT}/#{program['id']}", { headers: headers })

        json = extract_json(program, response)
        return scopes unless json

        parse_scopes(json, scopes)

        scopes
      end

      # Extracts JSON data from the HTTP response
      # @param program [Hash] Program information hash containing id
      # @param response [Faraday::Response] HTTP response
      # @return [Hash, nil] Parsed JSON data or nil if extraction fails
      def self.extract_json(program, response)
        unless response&.code == 200
          Discord.log_warn("Intigriti - Failed to fetch program #{program['name']} - #{response&.code}")
          return nil
        end

        json = Parser.json_parse(response.body)
        unless json
          Discord.log_warn("Intigriti - Failed to parse JSON for program #{program['handle']}")
          return nil
        end

        json = json.dig('domains', 'content')
        unless json
          Discord.log_warn("Intigriti - No content for program #{program['handle']}")
          return nil
        end

        json
      end

      def self.parse_scopes(json, scopes)
        return unless json.is_a?(Array)

        json.each do |scope|
          next unless valid_scope?(scope)

          category = find_category(scope)
          type = determine_scope_type(scope)

          scopes[type][category] ||= []

          add_scope(scopes, type, category, scope)
        end
      end

      def self.valid_scope?(scope)
        return false if scope.dig('tier', 'value') == 'No Bounty'

        category = find_category(scope)
        return false unless category
        return false if DENY.any? { |deny| scope['endpoint'].include?(deny) }

        true
      end

      def self.determine_scope_type(scope)
        scope.dig('tier', 'value') == 'Out Of Scope' ? 'out' : 'in'
      end

      def self.add_scope(scopes, type, category, scope)
        if category == :web && type == 'in'
          Normalizer.run('Intigriti', scope['endpoint'])&.each { |url| scopes[type][category] << url }
        else
          scopes[type][category] << scope['endpoint'].downcase
        end
      end

      def self.find_category(scope)
        category = CATEGORIES.find { |_key, values| values.include?(scope.dig('type', 'id')) }&.first
        Utilities.log_warn("Intigriti - Inexistent categories : #{scope}") if category.nil?

        category
      end
    end
  end
end
