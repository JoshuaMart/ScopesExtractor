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
          # Intigriti uses "domains" -> "content" for scopes list
          raw_scopes = data.dig('domains', 'content') || []

          scopes = raw_scopes.flat_map do |s|
            next if s.dig('tier', 'value') == 'No Bounty'

            normalize_scope(data['id'], s)
          end.compact

          Models::Program.new(
            id: data['id'],
            platform: 'intigriti',
            name: data['name'],
            bounty: data.dig('maxBounty', 'value').to_f.positive?,
            scopes: scopes
          )
        end

        def normalize_scope(program_id, raw_domain)
          type_id = raw_domain.dig('type', 'id')
          type = map_scope_type(type_id)

          is_in_scope = raw_domain.dig('tier', 'value') != 'Out Of Scope'

          endpoint = raw_domain['endpoint'].to_s
          return [] if endpoint.empty?

          values = if type == 'web' && is_in_scope
                     Normalizer.normalize('intigriti', endpoint)
                   else
                     [endpoint.downcase]
                   end

          values.map do |val|
            Models::Scope.new(
              program_id: program_id,
              value: val,
              type: type,
              is_in_scope: is_in_scope
            )
          end
        end

        def map_scope_type(type_id)
          case type_id
          when 1, 7 then 'web'
          when 2, 3 then 'mobile'
          when 8 then 'source_code'
          else 'other' # includes 4 (cidr), 5 (device), 6 (other)
          end
        end
      end
    end
  end
end
