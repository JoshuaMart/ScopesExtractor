# frozen_string_literal: true

require 'nokogiri'
require 'json'
require_relative 'scopes'

module ScopesExtractor
  module Immunefi
    # Programs module handles fetching and parsing bug bounty programs from Immunefi platform
    module Programs
      # Synchronizes Immunefi programs data
      # @param results [Hash] Hash to store the fetched programs data
      # @return [void]
      def self.sync(results)
        html = programs_page
        return unless html

        parse_programs(html, results)
      end

      # Fetches the Immunefi bug bounty programs page
      # @return [String, nil] HTML content of the bug bounty page or nil if request fails
      def self.programs_page
        response = HttpClient.get('https://immunefi.com/bug-bounty/')
        return unless response&.code == 200

        response.body
      end

      # Parses HTML content to extract program data
      # @param html [String] HTML content to parse
      # @param results [Hash] Hash to store the parsed programs data
      # @return [void]
      def self.parse_programs(html, results)
        programs = extract_programs(html)

        programs.each do |program|
          sleep(0.9) # Avoid rate limit
          title = program['project']

          program_info = { slug: program['id'], private: false }

          results[title] = program_info
          results[title]['scopes'] = Scopes.sync(program_info)
        end
      end

      # Extracts programs data from HTML using Nokogiri
      # @param html [String] HTML content to parse
      # @return [Array] Array of program hashes, empty array if extraction fails
      def self.extract_programs(html)
        doc = Nokogiri::HTML(html)
        next_data = doc.at_css('#__NEXT_DATA__')
        return [] unless next_data

        json = Parser.json_parse(next_data.text)
        return [] unless json

        # Retrieve program list from "props.pageProps.bounties"
        programs = json.dig('props', 'pageProps', 'bounties')
        return [] unless programs.is_a?(Array)

        programs
      end
    end
  end
end
