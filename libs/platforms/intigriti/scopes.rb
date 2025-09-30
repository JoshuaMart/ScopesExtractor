# frozen_string_literal: true

module ScopesExtractor
  module Intigriti
    # Intigriti Sync Scopes
    module Scopes
      CATEGORIES = {
        web: [1, 7],
        mobile: [2, 3],
        cidr: [4],
        device: [5],
        other: [6]
      }.freeze

      PROGRAMS_ENDPOINT = 'https://api.intigriti.com/external/researcher/v1/programs'
      DENY = ['.ripe.net'].freeze

      def self.sync(program, config)
        scopes = { 'in' => {}, 'out' => {} }

        url = "#{PROGRAMS_ENDPOINT}/#{program['id']}"
        response = get_with_retry(url, config, program['name'])

        return scopes unless response

        json = extract_json(program, response)
        return scopes unless json

        parse_scopes(json, scopes)
        scopes
      end

      def self.get_with_retry(url, config, program_name)
        headers = config.dig(:intigriti, :headers) || {}
        response = HttpClient.get(url, { headers: headers })

        return nil unless response_success?(response, config, program_name)

        response
      rescue StandardError => e
        Discord.log_warn(
          "Intigriti - Exception while fetching #{url}: #{e.class}: #{e.message}"
        )
        nil
      end

      def self.response_success?(response, config, program_name)
        return true if response&.code == 200

        skip403 = skip_403_error?(response, config)
        unless skip403
          Discord.log_warn(
            "Intigriti - Failed to fetch program #{program_name || '(unknown)'} " \
            "- #{response&.code}"
          )
        end
        false
      end

      def self.skip_403_error?(response, config)
        notify_403_errors = config.dig(:parser, :notify_intigriti_403_errors)
        response&.code == 403 && notify_403_errors == false
      end

      def self.extract_json(program, response)
        return nil unless response&.body

        json = Parser.json_parse(response.body)
        unless json
          Discord.log_warn(
            "Intigriti - Failed to parse JSON for program #{program['handle']}"
          )
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
          next unless category

          type = determine_scope_type(scope)
          scopes[type][category] ||= []
          add_scope(scopes, type, category, scope)
        end
      end

      def self.valid_scope?(scope)
        return false if scope.dig('tier', 'value') == 'No Bounty'

        category = find_category(scope)
        return false unless category

        endpoint = scope['endpoint'].to_s
        return false if endpoint.empty?
        return false if DENY.any? { |deny| endpoint.include?(deny) }

        true
      end

      def self.determine_scope_type(scope)
        scope.dig('tier', 'value') == 'Out Of Scope' ? 'out' : 'in'
      end

      def self.add_scope(scopes, type, category, scope)
        endpoint = scope['endpoint'].to_s
        return if endpoint.empty?

        if category == :web && type == 'in'
          Normalizer.run('Intigriti', endpoint)&.each do |url|
            scopes[type][category] << url
          end
        else
          scopes[type][category] << endpoint.downcase
        end
      end

      def self.find_category(scope)
        category = CATEGORIES.find { |_key, values| values.include?(scope.dig('type', 'id')) }&.first
        Utilities.log_warn("Intigriti - Inexistent categories : #{scope}") if category.nil?

        endpoint = scope['endpoint'].to_s
        ScopeCategoryDetector.adjust_category(category, endpoint)
      end
    end
  end
end
