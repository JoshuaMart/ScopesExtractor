# frozen_string_literal: true

class Bugcrowd
  # Bugcrowd Sync Programs
  class Scopes
    def self.sync(program, cookie)
      scopes = {}
      response = HttpClient.get("https://bugcrowd.com/#{program[:slug]}.json", cookie)
      return scopes unless response&.code == 200

      target_group_url = JSON.parse(response.body).dig('program', 'targetGroupsUrl')
      response = HttpClient.get(File.join('https://bugcrowd.com/', target_group_url), cookie)
      return scopes unless response&.code == 200

      targets_url = JSON.parse(response.body).dig('groups', 0, 'targets_url')
      return scopes unless targets_url

      response = HttpClient.get(File.join('https://bugcrowd.com/', targets_url), cookie)
      return scopes unless response&.code == 200

      in_scopes = JSON.parse(response.body)['targets']
      scopes['in'] = parse_scopes(in_scopes)

      scopes['out'] = {} # TODO

      scopes
    end

    def self.parse_scopes(scopes)
      exclusions = %w[}] # TODO : Try to normalize this
      scopes_normalized = []

      scopes.each do |scope|
        next unless scope['category'] == 'website' || scope['category'] == 'api'

        endpoint = scope['name'].split.first
        next if exclusions.any? { |exclusion| endpoint.include?(exclusion) } || !endpoint.include?('.')
        next if endpoint.include?('*') && !endpoint.start_with?('*.')

        scopes_normalized << endpoint
      end

      scopes_normalized
    end
  end
end
