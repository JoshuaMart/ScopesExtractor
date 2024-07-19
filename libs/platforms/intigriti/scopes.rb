# frozen_string_literal: true

module ScopesExtractor
  module Intigriti
    # Intigrit Sync Scopes
    module Scopes
      CATEGORIES = {
        url: [1, 7],
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
        scopes = {}

        url = File.join(PROGRAMS_ENDPOINT, program[:id])
        response = HttpClient.get(url, { headers: headers })
        return scopes unless response&.status == 200

        json = Parser.json_parse(response.body)
        return scopes unless json

        content = json.dig('domains', 'content')
        return scopes unless content

        parse_scopes(content)
      end

      def self.parse_scopes(data)
        scopes = { 'in' => {}, 'out' => {} }
        return scopes unless data.is_a?(Array)

        data.each do |scope|
          category = find_category(scope)
          next unless category
          next if DENY.any? { |deny| scope['endpoint'].include?(deny) }

          type = scope.dig('tier', 'value') == 'Out Of Scope' ? 'out' : 'in'

          scopes[type][category] ||= []
          endpoint = if category == :url
                       normalize(scope['endpoint'])
                     else
                       scope['endpoint'].downcase
                     end
          next unless endpoint

          scopes[type][category] << endpoint
        end

        scopes
      end

      def self.find_category(scope)
        category = CATEGORIES.find { |_key, values| values.include?(scope.dig('type', 'id')) }&.first
        Utilities.log_warn("Intigriti - Inexistent categories : #{scope}") if category.nil?

        category
      end

      def self.normalize(scope)
        scope = sanitize_scope(scope)
        scope.downcase!

        invalid_chars = [',', '{', '<', '[', '(', ' ']
        if invalid_chars.any? { |char| scope.include?(char) } || !scope.include?('.') || scope.split('.').last.size < 2
          Utilities.log_warn("Intigriti - Non-normalized scope : #{scope}")
          return
        end

        scope
      end

      def self.sanitize_scope(scope)
        scope.gsub('/*', '').gsub(' ', '').sub('.*', '.com').sub('.<TLD>', '.com')
                .sub(%r{/$}, '').sub(/\*$/, '').sub(/,$/, '')
      end
    end
  end
end
