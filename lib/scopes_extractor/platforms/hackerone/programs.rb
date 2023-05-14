# frozen_string_literal: true

require_relative 'scopes'

class Hackerone
  # Hackerone Sync Programs
  class Programs
    def self.sync(results, options, page_id = 1)
      programs_infos = programs_infos(page_id)
      return unless programs_infos

      programs_infos[:programs].each do |program|
        next unless program['attributes']['submission_state'] == 'open' && program['attributes']['offers_bounties']
        next if options[:skip_vdp] && !program['attributes']['offers_bounties']

        results[program['attributes']['name']] = program_info(program)
        results[program['attributes']['name']]['scopes'] = Scopes.sync(program_info(program))
      end

      sync(results, options, page_id + 1) if programs_infos[:next_page]
    end

    def self.program_info(program)
      {
        slug: program['attributes']['handle'],
        enabled: true,
        private: !program['attributes']['state'] == 'public_mode'
      }
    end

    def self.programs_infos(page_id)
      response = HttpClient.get("https://api.hackerone.com/v1/hackers/programs?page%5Bnumber%5D=#{page_id}")
      if response&.code == 429
        sleep 65 # Rate limit
        programs_infos(page_id)
      end
      return unless response.code == 200

      json_body = JSON.parse(response.body)
      { next_page: json_body['links']['next'], programs: json_body['data'] }
    end
  end
end
