# frozen_string_literal: true

require 'nokogiri'
require 'json'

module ScopesExtractor
  module Immunefi
    # Scopes module handles fetching and parsing scope information for Immunefi bug bounty programs
    module Scopes
      # Mapping of scope types to standardized categories
      CATEGORIES = {
        web: %w[websites_and_applications],
        contracts: %w[smart_contract],
        blockchain: %w[blockchain_dlt],
        source_code: %w[],
        mobile: %w[],
        other: %w[]
      }.freeze

      # Synchronizes scope information for an Immunefi program
      # @param program [Hash] Program information hash containing slug and private flag
      # @return [Hash] Hash of in-scope and out-of-scope items categorized
      def self.sync(program)
        scopes = { 'in' => {}, 'out' => {} }
        response = HttpClient.get("https://immunefi.com/bug-bounty/#{program[:slug]}/information/")

        json = extract_json(program, response)
        return scopes unless json

        bounty = json.dig('props', 'pageProps', 'bounty')
        unless bounty
          Discord.log_warn("Immunefi - No bounty data found for program #{program[:slug]}")
          return scopes
        end

        assets = bounty['assets']
        scopes['in'] = parse_scopes(assets)

        scopes
      end

      # Extracts JSON data from the HTTP response
      # @param program [Hash] Program information hash containing slug and private flag
      # @param response [Faraday::Response] HTTP response
      # @return [Hash, nil] Parsed JSON data or nil if extraction fails
      def self.extract_json(program, response)
        unless response&.code == 200
          Discord.log_warn("Immunefi - Failed to fetch program #{program[:slug]} - #{response&.code}")
          return nil
        end

        next_data = extract_next_data(program, response)
        return unless next_data

        json = Parser.json_parse(next_data.text)
        unless json
          Discord.log_warn("Immunefi - JSON parsing failed for program #{program[:slug]}")
          return nil
        end

        json
      end

      # Extracts NEXT_DATA element from the response HTML
      # @param program [Hash] Program information hash containing slug and private flag
      # @param response [Faraday::Response] HTTP response
      # @return [Nokogiri::XML::Element, nil] NEXT_DATA element or nil if not found
      def self.extract_next_data(program, response)
        html = response.body
        doc = Nokogiri::HTML(html)
        next_data = doc.at_css('#__NEXT_DATA__')
        unless next_data
          Discord.log_warn("Immunefi - __NEXT_DATA__ element not found for program #{program[:slug]}")
          return nil
        end

        next_data
      end

      # Parses scope data into categorized formats
      # @param data [Array] Array of scope data objects
      # @return [Hash] Categorized scope data
      def self.parse_scopes(data)
        return {} unless data.is_a?(Array)

        scopes = {}

        data.each do |infos|
          category = find_category(infos)
          next unless category

          scopes[category] ||= []
          scopes[category] << infos['url']
        end

        scopes
      end

      # Finds the standardized category for a scope item
      # @param infos [Hash] Scope item information
      # @return [Symbol, nil] Standardized category or nil if not found
      def self.find_category(infos)
        category = CATEGORIES.find { |_key, values| values.include?(infos['type']) }&.first
        Discord.log_warn("Immunefi - Unknown category: #{infos}") if category.nil?

        ScopeCategoryDetector.adjust_category(category, infos['url'])
      end
    end
  end
end
