# frozen_string_literal: true

module ScopesExtractor
  module YesWeHack
    # Scopes module handles fetching and parsing scope information for YesWeHack bug bounty programs
    module Scopes
      # Mapping of YesWeHack scope types to standardized categories
      CATEGORIES = {
        url: %w[web-application api ip-address],
        mobile: %w[mobile-application mobile-application-android mobile-application-ios],
        source_code: %w[],
        other: %w[other],
        executable: %w[application]
      }.freeze

      BASE_SCOPE_URL = 'https://api.yeswehack.com/programs'

      # Synchronizes scope information for a YesWeHack program
      # @param program [Hash] Program information hash containing slug
      # @param config [Hash] Configuration hash with authentication headers
      # @return [Hash] Hash of in-scope and out-of-scope items categorized
      def self.sync(program, config)
        scopes = { 'in' => {}, 'out' => {} }
        response = HttpClient.get("#{BASE_SCOPE_URL}/#{program[:slug]}", { headers: config[:headers] })

        json = extract_json(program, response)
        return scopes unless json

        scopes['in'] = parse_scopes(json['scopes'], true)
        scopes['out'] = parse_scopes(json['out_of_scope'], false)

        scopes
      end

      # Extracts JSON data from the HTTP response
      # @param program [Hash] Program information hash containing slug and private flag
      # @param response [Faraday::Response] HTTP response
      # @return [Hash, nil] Parsed JSON data or nil if extraction fails
      def self.extract_json(program, response)
        unless response&.status == 200
          Discord.log_warn("YesWeHack - Failed to fetch program #{program[:slug]} - #{response.status}")
          return nil
        end

        json = Parser.json_parse(response.body)
        unless json
          Discord.log_warn("YesWeHack - Failed to parse JSON for program #{program[:slug]}")
          return nil
        end

        json
      end

      # Parses scope data into categorized formats
      # @param data [Array] Array of scope data objects
      # @param in_scope [Boolean] Whether this is in-scope (true) or out-of-scope (false) data
      # @return [Hash] Categorized scope data
      def self.parse_scopes(data, in_scope)
        return {} unless data.is_a?(Array)

        scopes = {}

        data.each do |infos|
          category = find_category(infos, in_scope)
          next unless category

          scopes[category] ||= []
          add_scope_to_category(scopes, category, infos)
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
          Normalizer.run('YesWeHack', infos['scope'])&.each { |url| scopes[category] << url }
        else
          scopes[category] << infos['scope']
        end
      end

      # Finds the standardized category for a scope item
      # @param infos [Hash] Scope item information
      # @param in_scope [Boolean] Whether this is in-scope data (for warning purposes)
      # @return [Symbol, nil] Standardized category or nil if not found
      def self.find_category(infos, in_scope)
        category = CATEGORIES.find { |_key, values| values.include?(infos['scope_type']) }&.first
        Discord.log_warn("YesWeHack - Unknown category: #{infos}") if category.nil? && in_scope

        category = :source_code if source_code?(infos['scope'])

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
