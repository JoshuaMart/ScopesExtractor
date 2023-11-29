# frozen_string_literal: true

require_relative 'scopes'

module ScopesExtractor
  module Intigriti
    # Intigrit Sync Programs
    module Programs
      PROGRAMS_ENDPOINT = 'https://app.intigriti.com/api/core/researcher/programs'

      def self.sync(results, config)
        response = HttpClient.get(PROGRAMS_ENDPOINT, { headers: config[:headers] })
        return unless response&.status == 200

        programs = JSON.parse(response.body)
        parse_programs(programs, config, results)
      end

      def self.parse_programs(programs, config, results)
        programs.each do |program|
          next if !program['maxBounty']['value'].positive? || program['status'] == 4 # Suspended

          name = program['name']

          results['Intigriti'][name] = program_info(program)
          results['Intigriti'][name][:scopes] =
            Scopes.sync({ handle: program['handle'], company: program['companyHandle'] }, config[:headers])
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
end
