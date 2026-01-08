# frozen_string_literal: true

require 'base64'

module ScopesExtractor
  module Platforms
    module HackerOne
      class Platform < Platforms::Base
        def name
          'HackerOne'
        end

        def authenticate
          # Manual Basic Auth header for reliability
          auth = Base64.strict_encode64("#{@config[:username]}:#{@config[:token]}")
          @client.headers['Authorization'] = "Basic #{auth}"
          @authenticated = true
        end

        def fetch_programs
          authenticate unless @authenticated

          fetcher = ProgramFetcher.new(@client)
          raw_programs = fetcher.fetch_all

          raw_programs.map do |raw|
            attr = raw['attributes']
            next unless attr['offers_bounties'] == true && attr['submission_state'] == 'open'

            handle = attr['handle']
            scopes = fetcher.fetch_scopes(handle)

            parse_program(raw, scopes)
          rescue StandardError => e
            error_msg = "Error processing H1 program #{raw.dig('attributes', 'handle')}: #{e.message}"
            ScopesExtractor.logger.error "[HackerOne] #{error_msg}"
            ScopesExtractor.notifier.log('Program Fetch Error', error_msg, level: :error)
            nil
          end.compact
        end

        private

        def parse_program(raw_prog, raw_scopes)
          attr = raw_prog['attributes']
          handle = attr['handle']

          scopes = raw_scopes.flat_map do |s|
            s_attr = s['attributes']
            next if s_attr['eligible_for_submission'] == false # Out of scope

            normalize_scope(handle, s_attr)
          end.compact

          Models::Program.new(
            slug: handle,
            platform: 'hackerone',
            name: attr['name'],
            bounty: true, # We filtered for offers_bounties=true
            scopes: scopes
          )
        end

        def normalize_scope(handle, attr)
          type = map_scope_type(attr['asset_type'])
          values = Normalizer.normalize('hackerone', attr['asset_identifier'])

          values.map do |val|
            Models::Scope.new(
              program_id: handle,
              value: val,
              type: type,
              is_in_scope: true
            )
          end
        end

        def map_scope_type(h1_type)
          case h1_type
          when 'URL', 'WILDCARD', 'IP_ADDRESS', 'API' then 'web'
          when 'CIDR' then 'cidr'
          when 'GOOGLE_PLAY_APP_ID', 'ITUNES_APP_ID', 'APPLE_STORE_APP_ID' then 'mobile'
          when 'SOURCE_CODE', 'SMART_CONTRACT' then 'source_code'
          when 'DOWNLOADABLE_EXECUTABLES', 'WINDOWS_APP_STORE_APP_ID' then 'executable'
          else 'other'
          end
        end
      end
    end
  end
end
