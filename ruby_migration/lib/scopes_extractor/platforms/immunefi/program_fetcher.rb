# frozen_string_literal: true

require 'nokogiri'
require 'json'

module ScopesExtractor
  module Platforms
    module Immunefi
      class ProgramFetcher
        BASE_URL = 'https://immunefi.com'

        def initialize(client)
          @client = client
        end

        def fetch_all
          response = @client.get("#{BASE_URL}/bug-bounty/")
          return [] unless response.status == 200

          extract_programs_from_html(response.body)
        end

        def fetch_details(slug)
          response = @client.get("#{BASE_URL}/bug-bounty/#{slug}/information/")
          return nil unless response.status == 200

          extract_details_from_html(response.body)
        end

        private

        def extract_programs_from_html(html)
          json = extract_next_data(html)
          return [] unless json

          json.dig('props', 'pageProps', 'bounties') || []
        end

        def extract_details_from_html(html)
          json = extract_next_data(html)
          return nil unless json

          json.dig('props', 'pageProps', 'bounty')
        end

        def extract_next_data(html)
          doc = Nokogiri::HTML(html)
          next_data = doc.at_css('#__NEXT_DATA__')
          return nil unless next_data

          JSON.parse(next_data.text)
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
