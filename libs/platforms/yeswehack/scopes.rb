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
          normalize(infos['scope'])&.each { |url| scopes[category] << url }
        else
          scopes[category] << infos['scope']
        end
      end

      def self.find_category(infos, in_scope)
        category = CATEGORIES.find { |_key, values| values.include?(infos['scope_type']) }&.first
        Utilities.log_warn("YesWeHack - Inexistent categories : #{infos}") if category.nil? && in_scope

        category
      end

      def self.normalize(scope)
        normalized_scopes = []
        scope.sub!(/https?:\/\//, '') if scope.match?(/https?:\/\/\*\./)
        scope = scope.split(' ').first
        scope = scope[..-2] if scope.end_with?('/*')
        scope = "*#{scope}" if scope.start_with?('.')

        if (match = scope.match(/(?:https?:\/\/)?(?<prefix>\w+-)?\((?<subs>.*)\)(?<domain>.*)/))
          normalized = normalize_with_subdomains(match)
          normalized_scopes.concat(normalized)
        end

        if (match = scope.match(/^(?<base>.*)[\[(](?<tlds>[\w|]+)/))
          normalized = normalize_with_tlds(match)
          normalized_scopes.concat(normalized)
        end

        normalized_scopes << scope if normalized_scopes.empty?

        normalized_scopes.uniq!
        normalized_scopes.select do |s|
          unless scope_valid?(s)
            log_and_return(s)
            false
          else
            true
          end
        end
      end

      def self.scope_valid?(scope)
        invalid_chars = [',', '{', '<', '[', '(', ' ']
        if invalid_chars.any? { |char| scope.include?(char) } || !scope.include?('.')
          false
        else
          true
        end
      end

      def self.log_and_return(scope)
        Utilities.log_warn("YesWeHack - Non-normalized scope : #{scope}")
        nil
      end

      def self.normalize_with_subdomains(match)
        return [] if match[:subs]&.empty? || match[:domain]&.empty? || match[:domain] == '/'

        subs = match[:subs]
        subs.split('|').map { |sub| "#{match[:prefix]}#{sub}#{match[:domain]}" }
      end

      def self.normalize_with_tlds(match)
        return [] if match[:tlds]&.empty? || match[:base]&.empty? || match[:base].match?(/^https:\/\/(?:api-)?$/)

        tlds = match[:tlds]
        tlds.split('|').map { |tld| "#{match[:base]}#{tld}" }
      end
    end
  end
end
