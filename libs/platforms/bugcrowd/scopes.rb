# frozen_string_literal: true

module ScopesExtractor
  module Bugcrowd
    # Bugcrowd Sync Scopes
    module Scopes
      CATEGORIES = {
        url: %w[website api],
        mobile: %w[android ios],
        other: %w[other],
        executable: %w[application],
        hardware: %w[hardware]
      }.freeze

      # TODO : Improve this
      DENY = [
        'PTaaS Reference',
        'Gestor de pedidos - Web ONLY',
        'UA HOVR Equipped running shoe that you own or have authorization to test',
        'Kohl’s entire public digital footprint that is not Out-Of-Scope(See list below)',
        '.mybigcommerce.com/',
        'Smartchain Block Explorer',
        'Legacy Block Explorer'
      ].freeze

      def self.sync(brief_url)
        targets = extract_targets(brief_url)
        return unless targets

        {
          'in' => parse_scopes(targets),
          'out' => {} # TODO
        }
      end

      def self.parse_scopes(targets)
        scopes = {}

        targets.each do |target|
          category = find_category(target)
          next unless category

          scopes[category] ||= []
          next if DENY.any? { |deny| target['name'].include?(deny) }

          endpoint = if category == :url
                       normalize(target['name'])
                     else
                       target['name']
                     end
          next unless endpoint

          scopes[category] << endpoint if endpoint
        end

        scopes
      end

      def self.normalize(endpoint)
        endpoint = endpoint[..-2] if endpoint.end_with?('/*')
        endpoint.sub!(/https?:\/\//, '') if endpoint.match?(/https?:\/\/\*\./)

        scope = if !endpoint.start_with?('*.') && endpoint.include?('*.')
                  match = endpoint.match(/(?<wildcard>\*\.[\w.-]+\.\w+)/)
                  return unless match

                  match[:wildcard]
                else
                  endpoint
                end

        if ['<', '{'].any? { |char| scope.include?(char) }
          Utilities.log_warn("Bugcrowd - Non-normalized scope : #{scope}")
          return
        end

        scope.strip
      end

      def self.find_category(infos)
        category = CATEGORIES.find { |_key, values| values.include?(infos['category']) }&.first
        Utilities.log_warn("Bugcrowd - Inexistent categories : #{infos}") if category.nil?

        category
      end

      def self.extract_targets(brief_url)
        url = File.join('https://bugcrowd.com/', brief_url)

        if brief_url.start_with?('/engagements/')
          targets_from_engagements(url)
        else
          targets_from_groups(url)
        end
      end

      def self.targets_from_engagements(url)
        targets = nil
        response = HttpClient.get(url)
        return unless response&.status == 200

        match = response.body.match(/changelog\/(?<changelog>[-a-f0-9]+)/)
        return unless match

        url = File.join(url, 'changelog', "#{match[:changelog]}.json")
        response = HttpClient.get(url)
        return unless response&.status == 200

        json = Parser.json_parse(response.body)
        scopes = json.dig('data', 'scope')
        scopes&.each do |scope|
          next unless scope['name'] == 'In Scope Targets'

          targets = scope['targets']
        end

        targets
      end

      def self.targets_from_groups(url)
        url = File.join(url, 'target_groups')
        response = HttpClient.get(url)
        return unless response&.status == 200

        json = Parser.json_parse(response.body)

        targets_url = nil
        json['groups']&.each do |group|
          next unless group['name'] == 'In Scope Targets'

          targets_url = group['targets_url']
        end
        return unless targets_url

        url = File.join('https://bugcrowd.com/', targets_url)
        response = HttpClient.get(url)
        return scopes unless response&.status == 200

        json = Parser.json_parse(response.body)
        json['targets']
      end
    end
  end
end
