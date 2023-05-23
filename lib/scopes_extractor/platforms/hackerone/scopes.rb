# frozen_string_literal: true

class Hackerone
  # Hackerone Sync Programs
  class Scopes
    def self.sync(program)
      scopes = {}
      response = HttpClient.get("https://api.hackerone.com/v1/hackers/programs/#{program[:slug]}")
      return scopes unless response&.code == 200

      in_scopes = JSON.parse(response.body)['relationships']['structured_scopes']['data']
      scopes['in'] = parse_scopes(in_scopes)

      scopes['out'] = {} # TODO

      scopes
    end

    def self.parse_scopes(scopes)
      scopes_normalized = []

      scopes.each do |scope|
        next unless scope['attributes']['asset_type'] == 'URL'

        endpoint = scope['attributes']['asset_identifier']
        normalized = normalized(endpoint)

        normalized.each do |asset|
          next unless asset.include?('.')
          next if asset.include?('*') && !asset.start_with?('*.')

          scopes_normalized << asset
        end
      end

      scopes_normalized
    end

    def self.normalized(endpoint)
      endpoint.sub!(%r{/$}, '')

      normalized = []

      if endpoint.include?(',')
        endpoint.split(',').each { |asset| normalized << asset }
      else
        normalized << endpoint
      end

      normalized
    end
  end
end
