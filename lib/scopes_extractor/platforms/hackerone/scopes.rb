# frozen_string_literal: true

class Hackerone
  # Hackerone Sync Programs
  class Scopes
    def self.sync(program, options)
      scopes = {}
      response = HttpClient.get("https://api.hackerone.com/v1/hackers/programs/#{program[:slug]}")
      return scopes unless response&.code == 200

      in_scopes = JSON.parse(response.body)['relationships']['structured_scopes']['data']
      scopes['in'] = parse_scopes(in_scopes, options)

      scopes['out'] = {} # TODO

      scopes
    end

    def self.parse_scopes(scopes, options)
      scopes_normalized = []

      scopes.each do |scope|
        next if scope['attributes']['eligible_for_submission'] == false ||
          (scope['attributes']['eligible_for_bounty'] == false && options[:skip_vdp])
        next unless %w[URL WILDCARD].any?(scope['attributes']['asset_type'])

        endpoint = scope['attributes']['asset_identifier']
        normalized = normalized(endpoint)

        normalized.each do |asset|
          next unless asset.include?('.')
          next if asset.include?('*') && !asset.start_with?('*.')
          next unless asset.match?(/\w\./)

          scopes_normalized << asset.sub('/*', '')
        end
      end

      scopes_normalized
    end

    def self.normalized(endpoint)
      endpoint.sub!(%r{/$}, '')

      normalized = []

      if endpoint.include?(',')
        endpoint.split(',').each { |asset| normalized << asset.sub('/*', '') }
      else
        normalized << endpoint.sub('/*', '')
      end

      normalized
    end
  end
end
