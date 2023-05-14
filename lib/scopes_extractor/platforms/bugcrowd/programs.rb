# frozen_string_literal: true

require_relative 'scopes'

class Bugcrowd
  # Bugcrowd Sync Programs
  class Programs
    def self.sync(results, options, cookie, page_id = 1)
      response = HttpClient.get(
        "https://bugcrowd.com/programs.json?page[]=#{page_id}&waitlistable[]=false&joinable[]=false", cookie
      )
      return unless response&.code == 200

      body = JSON.parse(response.body)
      parse_programs(body['programs'], options, results, cookie)

      sync(results, options, cookie, page_id + 1) unless page_id == body['meta']['totalPages']
    end

    def self.parse_programs(programs, options, results, cookie)
      programs.each do |program|
        next if program['status'] == 4 # Disabled
        next if program['min_rewards'].nil? && options[:skip_vdp]

        results[program['name']] = program_info(program)
        results[program['name']]['scopes'] = Scopes.sync(program_info(program), cookie)
      end
    end

    def self.program_info(program)
      {
        slug: program['code'],
        enabled: true,
        private: false
      }
    end
  end
end
