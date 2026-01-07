# frozen_string_literal: true

module ScopesExtractor
  module Platforms
    module Intigriti
      class Platform < Platforms::Base
        def name
          'Intigriti'
        end

        def authenticate
          @client.headers['Authorization'] = "Bearer #{@config[:token]}"
          @authenticated = true
        end

        def fetch_programs
          authenticate unless @authenticated

          fetcher = ProgramFetcher.new(@client)
          raw_programs = fetcher.fetch_all

          raw_programs.map do |raw|
            # We need details for the "domains" (scopes)
            details = fetcher.fetch_details(raw['id'])
            next unless details

            parse_program(details)
          rescue StandardError => e
            error_msg = "Error fetching details for Intigriti program #{raw['id']}: #{e.message}"
            ScopesExtractor.logger.error "[Intigriti] #{error_msg}"
            ScopesExtractor.notifier.log('Program Fetch Error', error_msg, level: :error)
            nil
          end.compact
        end

        private

        def parse_program(data)
          # Intigriti uses "domains" for scopes
          raw_scopes = data['domains'] || []

          scopes = raw_scopes.flat_map do |s|
            # type 1 = URL, 2 = IP, 3 = Mobile, etc (Check API doc)
            # But let's use the object properties if available
            next if s['inScope'] == false

            normalize_scope(data['id'], s)
          end.compact

          Models::Program.new(
            id: data['id'],
            platform: 'intigriti',
            name: data['name'],
            bounty: data.dig('maxBounty', 'value').positive?,
            scopes: scopes
          )
        end

        def normalize_scope(program_id, raw_domain)
          type = map_scope_type(raw_domain['type'])
          values = Normalizer.normalize('intigriti', raw_domain['endpoint'])

          values.map do |val|
            Models::Scope.new(
              program_id: program_id,
              value: val,
              type: type,
              is_in_scope: true
            )
          end
        end

        def map_scope_type(intigriti_type)
          case intigriti_type
          when 'Url', 'IpAddress' then 'web'
          when 'Android', 'Ios' then 'mobile'
          else 'other'
          end
        end
      end
    end
  end
end
