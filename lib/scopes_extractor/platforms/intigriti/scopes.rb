# frozen_string_literal: true

require 'cgi'

class Intigriti
  # Intigrit Sync Programs
  class Scopes
    def self.sync(program, token)
      scopes = {}
      company = CGI.escape(program[:company])
      handle = CGI.escape(program[:handle])

      response = HttpClient.get("https://api.intigriti.com/core/researcher/programs/#{company}/#{handle}", token)
      return scopes unless response&.code == 200

      in_scopes = JSON.parse(response.body)['domains']&.last['content']
      scopes['in'] = parse_scopes(in_scopes)

      out_scopes = JSON.parse(response.body)['outOfScopes'].last['content']['content']
      scopes['out'] = out_scopes

      scopes
    end

    def self.parse_scopes(scopes)
      exclusions = %w[> | \] } Anyrelated] # TODO : Try to normalize this, it only concerns 1 or 2 programs currently
      scopes_normalized = []

      scopes.each do |scope|
        next unless scope['type'] == 1 || scope['type'] == 6 # 1 == Web Application || 6 == Other

        if scope['type'] == 1 # Web Application
          endpoint = normalize(scope['endpoint'])
          scopes_normalized << endpoint unless exclusions.any? { |exclusion| endpoint.include?(exclusion) } || !endpoint.include?('.')
        end

        endpoints_description = extract_description(scope['description'])
        endpoints_description&.each do |endpoint_description|
          endpoint_description = normalize(endpoint_description)
          scopes_normalized << endpoint_description unless exclusions.any? { |exclusion| endpoint_description.include?(exclusion) } || !endpoint_description.include?('.')
        end
      end

      scopes_normalized
    end

    def self.normalize(endpoint)
      endpoint.gsub('/*', '').gsub(' ', '').sub('.*', '.com').sub('.<tld>', '.com')
              .sub(%r{/$}, '').sub(/\*$/, '')
    end

    def self.extract_description(description)
      return [] unless description

      match = description.match(/In Scope(.*)Out of Scope/im)
      return unless match && match[1]

      match[1].scan(/\*\.[\w.-]+\.\w+/)
    end
  end
end
