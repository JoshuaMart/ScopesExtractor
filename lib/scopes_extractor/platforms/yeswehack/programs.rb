# frozen_string_literal: true

require_relative 'scopes'

class YesWeHack
  # YesWeHack Sync Programs
  class Programs
    def self.sync(results, options, jwt, page_id = 1)
      programs_infos = get_programs_infos(page_id, jwt)
      return unless programs_infos

      parse_programs(programs_infos, options, results, jwt)
      sync(results, options, jwt, page_id + 1) unless page_id == programs_infos[:nb_pages]
    end

    def self.get_programs_infos(page_id, jwt)
      response = HttpClient.get("https://api.yeswehack.com/programs?page=#{page_id}", jwt)
      return unless response&.code == 200

      json_body = JSON.parse(response.body)
      { nb_pages: json_body['pagination']['nb_pages'], programs: json_body['items'] }
    end

    def self.parse_programs(programs_infos, options, results, jwt)
      programs_infos[:programs].each do |program|
        next if program['disabled']
        next if program['vdp'] && options[:skip_vdp]

        results[program['title']] = program_info(program)
        results[program['title']]['scopes'] = Scopes.sync(program_info(program), jwt)
      end
    end

    def self.program_info(program)
      {
        slug: program['slug'],
        enabled: true,
        private: !program['public']
      }
    end
  end
end
