# frozen_string_literal: true

require_relative 'scopes'
require_relative '../../utilities/program_filter'

module ScopesExtractor
  module YesWeHack
    # Programs module handles fetching and parsing YesWeHack bug bounty programs
    module Programs
      PROGRAMS_URL = 'https://api.yeswehack.com/programs'

      # Synchronizes YesWeHack programs data, handling pagination
      # @param results [Hash] Hash to store the fetched programs data
      # @param config [Hash] Configuration hash with authentication headers
      # @param page_id [Integer] Page number for pagination, defaults to 1
      # @return [void]
      def self.sync(results, config, page_id = 1)
        page_infos = get_page_infos(page_id, config)
        return unless page_infos

        parse_programs(page_infos[:programs], results, config)
        sync(results, config, page_id + 1) unless page_id == page_infos[:nb_pages]
      end

      # Gets program information for a specific page
      # @param page_id [Integer] Page number to fetch
      # @param config [Hash] Configuration hash with authentication headers
      # @return [Hash, nil] Hash containing page count and programs, or nil on failure
      def self.get_page_infos(page_id, config)
        response = HttpClient.get("#{PROGRAMS_URL}?page=#{page_id}", { headers: config[:headers] })
        return unless response&.code == 200

        json = Parser.json_parse(response.body)
        return unless json

        { nb_pages: json.dig('pagination', 'nb_pages'), programs: json['items'] }
      end

      # Parses program data and adds it to the results hash
      # @param programs [Array] Array of program data objects
      # @param results [Hash] Hash to store the parsed program data
      # @param config [Hash] Configuration hash with authentication headers
      # @return [void]
      def self.parse_programs(programs, results, config)
        programs.each do |program|
          next if program['disabled'] || program['vdp']
          next if ProgramFilter.excluded?('yeswehack', program['slug'])

          title = program['title']

          program_info = { slug: program['slug'], private: !program['public'] }

          results[title] = program_info
          results[title]['scopes'] = Scopes.sync(program_info, config)
        end
      end
    end
  end
end
