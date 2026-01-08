# frozen_string_literal: true

module ScopesExtractor
  module Platforms
    module Immunefi
      class Platform < Platforms::Base
        def name
          'Immunefi'
        end

        def authenticate
          # No authentication needed for public scraping
          @authenticated = true
        end

        def fetch_programs
          fetcher = ProgramFetcher.new(@client)
          raw_programs = fetcher.fetch_all

          raw_programs.map do |raw|
            # Immunefi raw program has 'id' as slug, 'project' as name
            # We filter out closed programs if necessary (but fetch_all usually returns open ones from the list)
            # Original code filtered "excluded" programs but we handle exclusions globally.

            slug = raw['id']
            details = fetcher.fetch_details(slug)
            next unless details

            parse_program(details)
          rescue StandardError => e
            error_msg = "Error fetching details for Immunefi program #{raw['id']}: #{e.message}"
            ScopesExtractor.logger.error "[Immunefi] #{error_msg}"
            nil # Skip on error
          end.compact
        end

        private

        def parse_program(data)
          slug = data['id'] # or 'project' for name? check original
          # Original: title = program['project'], slug = program['id']
          name = data['project']

          assets = data['assets'] || []

          scopes = assets.flat_map do |asset|
            normalize_scope(slug, asset)
          end.compact

          Models::Program.new(
            id: slug,
            platform: 'immunefi',
            name: name,
            bounty: true, # safely assume yes for Immunefi
            scopes: scopes
          )
        end

        def normalize_scope(program_id, asset)
          type = map_scope_type(asset['type'])
          values = Normalizer.normalize('immunefi', asset['url'])

          values.map do |val|
            Models::Scope.new(
              program_id: program_id,
              value: val,
              type: type,
              is_in_scope: true
            )
          end
        end

        def map_scope_type(type_str)
          case type_str
          when 'websites_and_applications' then 'web'
          when 'smart_contract' then 'source_code'
          when 'blockchain_dlt' then 'other'
          else 'other'
          end
        end
      end
    end
  end
end
