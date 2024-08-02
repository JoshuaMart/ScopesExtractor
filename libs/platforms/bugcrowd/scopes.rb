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
        hardware: %w[hardware],
        iot: %w[iot],
        network: %w[network]
      }.freeze

      # TODO : Improve this
      DENY = [
        'PTaaS Reference',
        'Gestor de pedidos - Web ONLY',
        'UA HOVR Equipped running shoe that you own or have authorization to test',
        'Kohl’s entire public digital footprint that is not Out-Of-Scope(See list below)',
        '.mybigcommerce.com/',
        'Smartchain Block Explorer',
        'Legacy Block Explorer',
        'marketplace.atlassian.com'
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
        scope = Normalizer.general(endpoint)

        unless Normalizer.valid?(scope)
          Utilities.log_info("Bugcrowd - Non-normalized scope : #{endpoint}")
          return
        end

        scope
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
        targets = []
        response = HttpClient.get(url)
        return unless response&.status == 200

        match = response.body.match(%r{changelog/(?<changelog>[-a-f0-9]+)})
        return unless match

        url = File.join(url, 'changelog', "#{match[:changelog]}.json")
        response = HttpClient.get(url)
        return unless response&.status == 200

        json = Parser.json_parse(response.body)
        scopes = json.dig('data', 'scope')
        scopes&.each do |scope|
          next if ['oos', 'out of scope'].any? { |e| scope['name'].downcase.include?(e) }

          targets << scope['targets']
        end

        targets.flatten
      end

      def self.targets_from_groups(url)
        url = File.join(url, 'target_groups')
        response = HttpClient.get(url, { headers: { 'Accept' => 'application/json' }})
        return unless response&.status == 200

        json = Parser.json_parse(response.body)

        targets = []
        json['groups']&.each do |group|
          next unless group['in_scope']

          targets_url = group['targets_url']
          url = File.join('https://bugcrowd.com/', targets_url)
          response = HttpClient.get(url)
          return scopes unless response&.status == 200

          json = Parser.json_parse(response.body)
          targets << json['targets']
        end

        targets.flatten
      end
    end
  end
end
