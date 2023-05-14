# frozen_string_literal: true

require_relative 'scopes'

class Intigriti
  # Intigrit Sync Programs
  class Programs
    def self.sync(results, options, token)
      response = HttpClient.get('https://api.intigriti.com/core/researcher/programs', token)
      return unless response&.code == 200

      programs = JSON.parse(response.body)
      parse_programs(programs, options, results, token)
    end

    def self.parse_programs(programs, options, results, token)
      programs.each do |program|
        next if options[:skip_vdp] && !program['maxBounty']['value'].positive?
        next if program['status'] == 4 # Suspended

        results[program['name']] = program_info(program)
        results[program['name']]['scopes'] =
          Scopes.sync({ handle: program['handle'], company: program['companyHandle'] }, token)
      end
    end

    def self.program_info(program)
      {
        slug: program['handle'],
        enabled: true,
        private: program['confidentialityLevel'] != 4 # == public
      }
    end
  end
end
