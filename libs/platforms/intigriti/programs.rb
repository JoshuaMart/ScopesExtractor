# frozen_string_literal: true

require_relative 'scopes'

module ScopesExtractor
  module Intigriti
    # Intigrit Sync Programs
    module Programs
      PROGRAMS_ENDPOINT = 'https://api.intigriti.com/external/researcher/v1/programs'

      def self.sync(results, config)
        response = HttpClient.get(PROGRAMS_ENDPOINT, { headers: config[:headers] })
        return unless response&.status == 200

        data = Parser.json_parse(response.body)
        return unless data

        parse_programs(data['records'], config, results)
      end

      def self.parse_programs(programs, config, results)
        programs&.each do |program|
          next if !program['maxBounty']['value'].positive? || program.dig('status', 'value') == 'Suspended'

          name = program['name']

          results['Intigriti'][name] = program_info(program)
          results['Intigriti'][name][:scopes] =
            Scopes.sync({ id: program['id'] }, config[:headers])
        end
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
