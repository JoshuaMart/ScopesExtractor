# frozen_string_literal: true

class YesWeHack
  # YesWeHack Sync Scopes
  class Scopes
    def self.sync(program, jwt)
      scopes = {}
      response = HttpClient.get("https://api.yeswehack.com/programs/#{program[:slug]}", jwt)
      return scopes unless response&.code == 200

      in_scopes = JSON.parse(response.body)['scopes']
      scopes['in'] = parse_scopes(in_scopes)

      out_scopes = JSON.parse(response.body)&.dig('out_of_scope')
      scopes['out'] = out_scopes

      scopes
    end

    def self.parse_scopes(scopes)
      scopes_normalized = []

      scopes.each do |infos|
        next unless %w[web-application api].include?(infos['scope_type'])

        normalized = normalize(infos['scope'])
        normalized.each do |asset|
          scopes_normalized << asset
        end
      end

      scopes_normalized
    end

    def self.normalize(scope)
      # Remove (+++) & When end with '*'
      scope = scope.gsub(/\(?\+\)?/, '').sub(/\*$/, '').strip
      return [] if scope.include?('<') # <yourdomain>-yeswehack.domain.tld

      normalized = []

      match = scope.match(/^(.*)\((.*)\)$/) # Ex: *.lazada.(sg|vn|co.id|co.th|com|com.ph|com.my)
      if match && match[1] && match[2]
        tlds = match[2].split('|')
        tlds.each { |tld| normalized << "#{match[1]}#{tld}" }
      elsif scope.include?(' ')
        normalized << scope.split(' ')[0]
      elsif scope.match?(%r{https?://\*})
        normalized << scope.sub(%r{https?://}, '')
      else
        normalized << scope
      end

      normalized
    end
  end
end
