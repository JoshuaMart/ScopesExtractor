# frozen_string_literal: true

module ScopesExtractor
  module YesWeHack
    # YesWeHack Sync Scopes
    module Scopes
      CATEGORIES = {
        url: %w[web-application api ip-address],
        mobile: %w[mobile-application mobile-application-android mobile-application-ios],
        other: %w[other],
        executable: %w[application]
      }.freeze

      def self.sync(program, config)
        scopes = {}
        response = HttpClient.get("https://api.yeswehack.com/programs/#{program[:slug]}", { headers: config[:headers] })
        return scopes unless response&.status == 200

        json = Parser.json_parse(response.body)
        return scopes unless json

        scopes['in'] = parse_scopes(json['scopes'], true)
        scopes['out'] = parse_scopes(json['out_of_scope'], false)

        scopes
      end

      def self.parse_scopes(data, in_scope)
        scopes = {}

        data.each do |infos|
          category = find_category(infos, in_scope)
          next unless category

          scopes[category] ||= []
          add_scope_to_category(scopes, category, infos)
        end

        scopes
      end

      def self.add_scope_to_category(scopes, category, infos)
        if category == :url
          normalize_urls(infos['scope']).each { |url| scopes[category] << url }
        else
          scopes[category] << infos['scope']
        end
      end

      def self.find_category(infos, in_scope)
        category = CATEGORIES.find { |_key, values| values.include?(infos['scope_type']) }&.first
        Utilities.log_warn("YesWeHack - Inexistent categories : #{infos}") if category.nil? && in_scope

        category
      end

      def self.normalize_urls(scope)
        normalized_urls = []
        scope = sanitize_scope(scope)

        if (match_data = scope.match(/^\((.*)\)(.*)/))
          normalized_urls.concat(normalize_with_subdomains(match_data[1], match_data[2]))
        elsif (match_data = scope.match(/^(.*)[\[(]([\w|]+)/))
          normalized_urls.concat(normalize_with_tlds(match_data[1], match_data[2]))
        elsif scope.match?(%r{https?://\*})
          normalized_urls << scope.sub(%r{https?://}, '')
        elsif scope.match?(%r{^(https?://|\*\.)[/\w.\-?#!%:=]+$}) || scope.match?(%r{^[/\w.-]+\.[a-z]+(/.*)?})
          normalized_urls << scope
        else
          Utilities.log_warn("YesWeHack - Non-normalized scope : #{scope}")
        end

        normalized_urls.uniq
      end

      def self.sanitize_scope(scope)
        scope.split(' ')[0].gsub(%r{(/\*|\)/)$}, '')
      end

      def self.normalize_with_subdomains(subs, domain)
        subs.split('|').map { |sub| "#{sub}#{domain}" }
      end

      def self.normalize_with_tlds(base, tlds)
        tlds.split('|').map { |tld| "#{base}#{tld}" }
      end
    end
  end
end
