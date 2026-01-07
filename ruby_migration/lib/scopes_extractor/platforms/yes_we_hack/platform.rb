# frozen_string_literal: true

module ScopesExtractor
  module Platforms
    module YesWeHack
      class Platform < Platforms::Base
        def name
          'YesWeHack'
        end

        def authenticate
          @authenticator ||= Authenticator.new(
            email: @config[:email],
            password: @config[:password],
            otp_secret: @config[:otp],
            client: @client
          )
          @token = @authenticator.authenticate
        end

        def fetch_programs
          authenticate unless @token

          fetcher = ProgramFetcher.new(@client, @token)
          raw_programs = fetcher.fetch_all

          raw_programs.map do |raw|
            # We need full details to get the scopes
            details = fetcher.fetch_details(raw['slug'])
            next unless details

            parse_program(details)
          rescue StandardError => e
            error_msg = "Error fetching details for YWH program #{raw['slug']}: #{e.message}"
            ScopesExtractor.logger.error "[YesWeHack] #{error_msg}"
            ScopesExtractor.notifier.log('Program Fetch Error', error_msg, level: :error)
            nil
          end.compact
        end

        private

        def parse_program(data)
          # In-scope
          in_scopes = (data['scopes'] || []).flat_map do |s|
            normalize_scope(data['slug'], s, true)
          end

          # Out-of-scope
          out_scopes = (data['out_of_scope'] || []).flat_map do |s|
            normalize_scope(data['slug'], s, false)
          end

          Models::Program.new(
            id: data['slug'],
            platform: 'yeswehack',
            name: data['title'],
            bounty: data['bounty'] == true,
            scopes: in_scopes + out_scopes
          )
        end

        def normalize_scope(slug, raw_scope, is_in_scope)
          type = map_scope_type(raw_scope['scope_type'])
          values = Normalizer.normalize('yeswehack', raw_scope['scope'])

          values.map do |val|
            Models::Scope.new(
              program_id: slug,
              value: val,
              type: type,
              is_in_scope: is_in_scope
            )
          end
        end

        def map_scope_type(ywh_type)
          case ywh_type
          when 'web-application', 'api', 'ip-address', 'wildcard' then 'web'
          when 'mobile-application', 'mobile-application-android', 'mobile-application-ios' then 'mobile'
          when 'open-source' then 'source_code'
          when 'application' then 'executable'
          else 'other'
          end
        end
      end
    end
  end
end
