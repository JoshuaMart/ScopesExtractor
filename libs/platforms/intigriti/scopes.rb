# frozen_string_literal: true

require 'cgi'

module ScopesExtractor
  module Intigriti
    # Intigrit Sync Scopes
    module Scopes
      CATEGORIES = {
        url: [1],
        mobile: [2, 3],
        cidr: [4],
        device: [5],
        other: [6]
      }.freeze

      PROGRAMS_ENDPOINT = 'https://app.intigriti.com/api/core/researcher/programs'

      def self.sync(program, headers)
        scopes = {}

        url = prepare_scope_url(program)
        response = HttpClient.get(url, headers)
        return scopes unless response&.status == 200

        json = Parser.json_parse(response.body)
        return scopes unless json

        in_scopes = json['domains']&.last&.[]('content')
        scopes['in'] = parse_scopes(in_scopes, true)

        out_scopes = json['outOfScopes'].last.dig('content', 'content')
        scopes['out'] = parse_scopes(out_scopes, false)

        scopes
      end

      def self.prepare_scope_url(program)
        company = CGI.escape(program[:company])
        handle = CGI.escape(program[:handle])

        File.join(PROGRAMS_ENDPOINT, company, handle)
      end

      def self.parse_scopes(scopes, in_scope)
        categorized_scopes = {}
        return categorized_scopes unless scopes.is_a?(Array)

        scopes.each do |scope|
          category = find_category(scope, in_scope)
          next unless category

          categorized_scopes[category] ||= []
          categorized_scopes[category] << case scope['type']
                                          when 1
                                            normalize(scope['endpoint'])
                                          else
                                            scope['endpoint']
                                          end

          scope['endpoint']
        end

        categorized_scopes
      end

      def self.find_category(scope, in_scope)
        category = CATEGORIES.find { |_key, values| values.include?(scope['type']) }&.first
        Utilities.log_warn("Intigriti - Inexistent categories : #{scope}") if category.nil? && in_scope

        category
      end

      def self.normalize(endpoint)
        endpoint = sanitize_endpoint(endpoint)

        if endpoint.match?(%r{^(https?://|\*\.)[/\w.\-?#!%:=]+$}) || endpoint.match?(%r{^[/\w.-]+\.[a-z]+$})
          endpoint
        else
          Utilities.log_warn("Intigriti - Non-normalized endpoint : #{endpoint}")
          nil
        end
      end

      def self.sanitize_endpoint(endpoint)
        endpoint.gsub('/*', '').gsub(' ', '').sub('.*', '.com').sub('.<TLD>', '.com')
                .sub(%r{/$}, '').sub(/\*$/, '').sub(/,$/, '')
      end
    end
  end
end
