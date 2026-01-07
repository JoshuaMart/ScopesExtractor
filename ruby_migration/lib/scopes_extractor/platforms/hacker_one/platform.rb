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
            # Details are needed for structured scopes
            handle = raw.dig('attributes', 'handle')
            details = fetcher.fetch_details(handle)
            next unless details

            parse_program(details['data'])
          rescue StandardError => e
            error_msg = "Error fetching details for H1 program #{raw.dig('attributes', 'handle')}: #{e.message}"
            ScopesExtractor.logger.error "[HackerOne] #{error_msg}"
            ScopesExtractor.notifier.log('Program Fetch Error', error_msg, level: :error)
            nil
          end.compact
        end

        private

        def parse_program(data)
          handle = data.dig('attributes', 'handle')

          # H1 API provides scopes in structured format
          raw_scopes = data.dig('relationships', 'structured_scopes', 'data') || []

          scopes = raw_scopes.flat_map do |s|
            attr = s['attributes']
            next if attr['eligible_for_submission'] == false # Out of scope

            normalize_scope(handle, attr)
          end.compact

          Models::Program.new(
            id: handle,
            platform: 'hackerone',
            name: data.dig('attributes', 'name'),
            bounty: data.dig('attributes', 'offers_bounties') == true,
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
          when 'URL', 'WILDCARD', 'IP_ADDRESS', 'CIDR' then 'web'
          when 'GOOGLE_PLAY_APP_ID', 'ITUNES_APP_ID' then 'mobile'
          else 'other'
          end
        end
      end
    end
  end
end
