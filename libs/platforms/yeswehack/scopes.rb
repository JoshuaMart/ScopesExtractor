# frozen_string_literal: true

module ScopesExtractor
  module YesWeHack
    # YesWeHack Sync Scopes
    module Scopes
      CATEGORIES = {
        url: %w[web-application api ip-address],
        mobile: %w[mobile-application mobile-application-android mobile-application-ios],
        other: %w[other],
        executable: %w[application]
      }.freeze

      def self.sync(program, config)
        scopes = {}
        response = HttpClient.get("https://api.yeswehack.com/programs/#{program[:slug]}", { headers: config[:headers] })
        return scopes unless response&.code == 200

        json = Parser.json_parse(response.body)
        return unless json

        scopes['in'] = parse_scopes(json['scopes'])
        scopes['out'] = parse_scopes(json['out_of_scope'])

        scopes
      end

      def self.parse_scopes(scopes)
        normalized = {}

        scopes.each do |infos|
          category_name = CATEGORIES.find { |_key, values| values.include?(infos['scope_type']) }&.first
          if category_name.nil?
            Utilities.log_warn("YesWeHack - Inexistent categories : #{infos['scope_type']} - #{infos['scope']}")
            next
          end

          normalized[category_name] = [] unless normalized[category_name]
          normalized[category_name] << infos['scope']
        end

        normalized
      end
    end
  end
end
