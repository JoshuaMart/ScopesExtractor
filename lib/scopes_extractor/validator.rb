# frozen_string_literal: true

require 'public_suffix'

module ScopesExtractor
  module Validator
    def self.valid_web_target?(value, type)
      # We only enforce strict format for web/api types
      return true unless %w[web api].include?(type.to_s)

      val = value.to_s.strip

      return false unless valid_basic_structure?(val)
      return false unless valid_wildcard_usage?(val)

      true
    end

    def self.valid_basic_structure?(val)
      # 1. Must have at least one dot OR be a valid URL (to support http://localhost)
      return false unless val.include?('.') || val.match?(%r{^https?://})

      # 2. Must NOT contain any spaces
      return false if val.include?(' ')

      # 3. Must NOT contain brackets, chevrons, or template placeholders like %
      # '?' is allowed in query string but handled separately for host
      return false if val.match?(/[!()\[\]<>%]/)

      # 3b. Must NOT contain curly braces (often used for placeholders {id})
      return false if val.match?(/[{}]/)

      # 4. '#' and '?' are allowed ONLY in the fragment/path/query part, NOT in the domain
      if val.match?(/[#?]/)
        # Extract host: everything before the first slash (ignoring protocol slashes)
        cleaned = val.sub(%r{^https?://}, '')

        # Get potential host part (stop at first slash)
        host_candidate = cleaned.split('/', 2).first

        # If host part contains '?', it marks start of query string (e.g. example.com?q=1)
        # So the real host is before that.
        host = host_candidate.split('?', 2).first

        # Reject if the extracted host contains '#' (invalid inside domain)
        return false if host.include?('#')
      end

      # 5. Minimum length (e.g., "a.bc")
      return false if val.length < 4

      true
    end

    def self.valid_wildcard_usage?(val)
      return true unless val.include?('*')

      # 1. Wildcards must be at start only: "*.example.com"
      return false unless val.start_with?('*.')

      # 2. No double wildcards: "*.sub*.example.com"
      return false if val.count('*') > 1

      # 3. No paths allowed in wildcard domains: "*.example.com/login"
      return false if val.include?('/')

      # 4. Domain part cannot start with a hyphen: "*.-example.com"
      domain_part = val[2..]
      return false if domain_part&.start_with?('-')

      # 5. Domain part must be a valid registrable domain (not just a public suffix like *.co.uk)
      begin
        parsed = PublicSuffix.parse(domain_part, ignore_private: Config.allow_private_suffixes?)
        return false if parsed.sld.nil?
      rescue PublicSuffix::DomainInvalid, PublicSuffix::DomainNotAllowed
        return false
      end

      true
    end
  end
end
