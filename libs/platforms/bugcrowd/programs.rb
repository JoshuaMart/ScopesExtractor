# frozen_string_literal: true

require_relative 'scopes'

module ScopesExtractor
  module Bugcrowd
    # Bugcrowd Sync Programs
    module Programs
      PROGRAMS_ENDPOINT = 'https://bugcrowd.com/engagements.json'

      def self.sync(results, page_id = 1)
        url = File.join(PROGRAMS_ENDPOINT, "?page=#{page_id}&category=bug_bounty")
        resp = HttpClient.get(url)
        return unless resp&.code == 200

        body = Parser.json_parse(resp.body)
        return if body['engagements'].empty?

        parse_programs(body['engagements'], results)
        sync(results, page_id + 1)
      end

      def self.parse_programs(programs, results)
        programs.each do |program|
          next unless program['accessStatus'] == 'open'

          infos = program_info(program)
          scopes = Scopes.sync(program)

          results[program['name']] = infos
          results[program['name']]['scopes'] = scopes
        end
      end

      def self.program_info(program)
        slug = program['briefUrl'][1..]
        {
          slug: slug,
          enabled: true,
          private: false
        }
      end
    end
  end
end
