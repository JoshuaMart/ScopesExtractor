# frozen_string_literal: true

require_relative 'scopes'
require_relative '../../utilities/program_filter'

module ScopesExtractor
  module Intigriti
    # Intigrit Sync Programs
    module Programs
      PROGRAMS_ENDPOINT = 'https://api.intigriti.com/external/researcher/v1/programs?limit=500&statusId=3'

      def self.sync(results, config)
        response = HttpClient.get(PROGRAMS_ENDPOINT, { headers: config[:intigriti][:headers] })
        return unless response&.code == 200

        data = Parser.json_parse(response.body)
        return unless data

        parse_programs(data['records'], config, results)
      end

      def self.parse_programs(programs, config, results)
        programs&.each do |program|
          next if skip_program?(program)
          next if ProgramFilter.excluded?('intigriti', program['handle'])

          sleep(0.3) # Avoid rate limit
          name = program['name']

          results[name] = program_info(program)
          results[name][:scopes] = Scopes.sync(program, config)
        end
      end

      def self.skip_program?(program)
        !program['maxBounty']['value'].positive?
      end

      def self.program_info(program)
        {
          slug: program['handle'],
          enabled: true,
          private: program.dig('confidentialityLevel', 'id') != 4 # == public
        }
      end
    end
  end
end
