# frozen_string_literal: true

module ScopesExtractor
  module Platforms
    module Bugcrowd
      class Platform < Platforms::Base
        def name
          'Bugcrowd'
        end

        def authenticate
          @authenticator ||= Authenticator.new(
            email: @config[:email],
            password: @config[:password],
            otp_secret: @config[:otp],
            client: @client
          )
          @authenticated = @authenticator.authenticate
        end

        def fetch_programs
          authenticate unless @authenticated

          fetcher = ProgramFetcher.new(@client)
          raw_programs = fetcher.fetch_all

          raw_programs.map do |raw|
            slug = raw['briefUrl'][1..] # Remove leading slash
            raw_scopes = fetcher.fetch_scopes(raw['briefUrl'])

            parse_program(raw, slug, raw_scopes)
          rescue StandardError => e
            error_msg = "Error fetching scopes for Bugcrowd program #{raw['briefUrl']}: #{e.message}"
            ScopesExtractor.logger.error "[Bugcrowd] #{error_msg}"
            ScopesExtractor.notifier.log('Program Fetch Error', error_msg, level: :error)
            nil
          end.compact
        end

        private

        def parse_program(raw, slug, raw_scopes)
          scopes = raw_scopes.flat_map do |s|
            normalize_scope(slug, s)
          end

          Models::Program.new(
            id: slug,
            platform: 'bugcrowd',
            name: raw['name'],
            # In engagements JSON, bounty status is not always obvious,
            # but usually engagements=bug bounty
            bounty: true,
            scopes: scopes
          )
        end

        def normalize_scope(slug, target)
          type = map_scope_type(target['category'])
          values = Normalizer.normalize('bugcrowd', target['name'])

          values.map do |val|
            Models::Scope.new(
              program_id: slug,
              value: val,
              type: type,
              is_in_scope: true
            )
          end
        end

        def map_scope_type(bc_type)
          case bc_type
          when 'website', 'api', 'ip_address', 'network' then 'web'
          when 'android', 'ios' then 'mobile'
          else 'other'
          end
        end
      end
    end
  end
end
