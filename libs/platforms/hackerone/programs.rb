# frozen_string_literal: true

require_relative 'scopes'

module ScopesExtractor
  module Hackerone
    # Hackerone Sync Programs
    module Programs
      PROGRAMS_ENDPOINT = 'https://api.hackerone.com/v1/hackers/programs'

      def self.sync(results, config, page_id = 1)
        page_infos = get_programs_infos(page_id, config)
        return unless page_infos

        parse_programs(page_infos[:programs], config, results)
        sync(results, config, page_id + 1) if page_infos[:next_page]
      end

      def self.parse_programs(programs, config, results)
        programs.each do |program|
          attributes = program['attributes']
          next unless attributes['submission_state'] == 'open' && attributes['offers_bounties']

          name = attributes['name']
          results['Hackerone'][name] = program_info(program)
          results['Hackerone'][name]['scopes'] = Scopes.sync(program_info(program), config)
        end
      end

      def self.program_info(program)
        {
          slug: program['attributes']['handle'],
          enabled: true,
          private: !program['attributes']['state'] == 'public_mode'
        }
      end

      def self.get_programs_infos(page_id, config)
        url = PROGRAMS_ENDPOINT + "?page%5Bnumber%5D=#{page_id}"
        response = HttpClient.get(url, { headers: config[:headers] })
        if response&.status == 429
          sleep 65 # Rate limit
          programs_infos(page_id)
        end
        return unless response.status == 200

        json = Parser.json_parse(response.body)
        return unless json

        { next_page: json.dig('links', 'next'), programs: json['data'] }
      end
    end
  end
end