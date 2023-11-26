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
        return scopes unless response&.code == 200

        json = Parser.json_parse(response.body)
        return unless json

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

      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      def self.normalize_urls(scope)
        normalized_urls = []

        scope = scope.split(' ')[0]
        scope = scope[..-2] if scope.end_with?('/*')
        scope = scope[..-2] if scope.end_with?(')/')

        # Ex: (a|b|c).domain.tld
        multi_subs = scope.match(/^\((.*)\)(.*)/)

        # Ex: *.domain.(a|b|c)
        multi_tld = scope.match(/^(.*)[\[(](.*)[\])]$/)

        if multi_tld && multi_tld[1] && multi_tld[2]
          tlds = multi_tld[2].split('|')
          tlds.each { |tld| normalized_urls << "#{multi_tld[1]}#{tld}" }
        elsif multi_subs && multi_subs[1] && multi_subs[2]
          subs = multi_subs[1].split('|')
          subs.each { |sub| normalized_urls << "#{sub}#{multi_subs[2]}" }
        elsif scope.match?(%r{https?://\*})
          normalized_urls << scope.sub(%r{https?://}, '')
        elsif !scope.match?(%r{^(https?://|\*\.)[/\w.\-?#!%:=]+$}) && !scope.match?(%r{^^[/\w.-]+$})
          Utilities.log_warn("YesWeHack - Non-normalized scope : #{scope}")
          normalized_urls << scope
        else
          normalized_urls << scope
        end

        normalized_urls
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity
    end
  end
end
