# frozen_string_literal: true

require_relative 'scopes'

module ScopesExtractor
  module YesWeHack
    # YesWeHack Sync Programs
    module Programs
      def self.sync(results, config, page_id = 1)
        page_infos = get_page_infos(page_id, config)
        return unless page_infos

        parse_programs(page_infos[:programs], results, config)
        sync(results, config, page_id + 1) unless page_id == page_infos[:nb_pages]
      end

      def self.get_page_infos(page_id, config)
        response = HttpClient.get("https://api.yeswehack.com/programs?page=#{page_id}", { headers: config[:headers] })
        return unless response&.status == 200

        json = Parser.json_parse(response.body)
        return unless json

        { nb_pages: json.dig('pagination', 'nb_pages'), programs: json['items'] }
      end

      def self.parse_programs(programs, results, config)
        programs.each do |program|
          next if program['disabled'] || program['vdp']

          title = program['title']
          program_info = { slug: program['slug'], private: !program['public'] }

          results[title] = program_info
          results[title]['scopes'] = Scopes.sync(program_info, config)
        end
      end
    end
  end
end
