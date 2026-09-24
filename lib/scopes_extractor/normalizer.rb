# frozen_string_literal: true

module ScopesExtractor
  module Normalizer
    HOST_ALTERNATIVES_REGEX = /
      \A(?<prefix>[^()\[\]]*)
      (?<open>\(|\[)
      (?<options>[^()\[\]]+)
      (?<close>\)|\])
      (?<suffix>[^()\[\]]*)\z
    /x
    ALTERNATIVE_REGEX = %r{\A[a-z0-9][a-z0-9._/-]*\z}
    MAX_ALTERNATIVES = 100

    def self.normalize(platform, value)
      value = global_normalization(value)

      normalized = case platform.downcase
                   when 'yeswehack' then normalize_yeswehack(value)
                   when 'intigriti' then normalize_intigriti(value)
                   when 'hackerone' then normalize_hackerone(value)
                   when 'bugcrowd' then normalize_bugcrowd(value)
                   else [value]
                   end

      # Final cleanup and deduplication
      normalized.map(&:strip).reject(&:empty?).uniq
    end

    def self.global_normalization(value)
      value = value.to_s.strip.delete("\u00AD")

      # Remove protocol only if it's a wildcard (not a valid URL anymore)
      value = value.sub(%r{^https?://}, '') if value.include?('*')

      # Clean up spaces after leading wildcards (e.g., "*. example.com" or "* .example.com")
      value = value.sub(/^\*\s*\.?\s*/, '*.')

      # Replace escaped slashes
      value = value.gsub('\\/', '/')

      # Strip trailing slashes or path wildcards
      value = global_end_strip(value)

      # Handle leading dot
      value = "*#{value}" if value.start_with?('.')

      value.downcase.delete_suffix('\\')
    end

    def self.global_end_strip(value)
      value = value.delete_suffix('/*')
      value = value.delete_suffix('/')

      # Remove leading * if not followed by .
      value = value.delete_prefix('*') if value.start_with?('*') && !value.start_with?('*.')

      value.strip
    end

    def self.normalize_yeswehack(value)
      match = value.match(HOST_ALTERNATIVES_REGEX)
      return [value] unless expandable_host_pattern?(match)

      explicit_options = host_options(match)
      return [value] if explicit_options.empty?

      explicit_options.map { |option| "#{match[:prefix]}#{option}#{match[:suffix]}" }
    end

    def self.expandable_host_pattern?(match)
      return false unless match
      return false unless { '(' => ')', '[' => ']' }[match[:open]] == match[:close]

      # The group must appear in the hostname, before a path, query, fragment, port, or userinfo.
      host_prefix = match[:prefix].sub(%r{\A[a-z][a-z0-9+.-]*://}, '')
      !host_prefix.match?(%r{[/?#@:]})
    end

    def self.host_options(match)
      options = match[:options].split('|', -1).map(&:strip)
      return [] unless options.size.between?(2, MAX_ALTERNATIVES)

      explicit_options = options.reject { |option| %w[… ...].include?(option) }
      return [] unless explicit_options.all? { |option| valid_host_option?(option, match) }

      explicit_options
    end

    def self.valid_host_option?(option, match)
      return false unless option.match?(ALTERNATIVE_REGEX)
      return true unless option.include?('/')

      # Existing YesWeHack patterns may include a path in a complete TLD alternative.
      match[:prefix].end_with?('.') && match[:suffix].empty?
    end

    def self.normalize_intigriti(value)
      # Replace <tld> or <TLD> patterns with .com
      value = value.gsub(/\.<tld>/i, '.com')

      # Replace .* patterns with .com
      value = value.sub('.*', '.com')

      # Handle slash-separated values (e.g., "www.example.kz / www.example.com")
      if value.include?(' / ')
        value.split(' / ')
      else
        [value]
      end
    end

    def self.normalize_hackerone(value)
      # Replace .* patterns with .com
      value = value.sub('.*', '.com')

      # Replace .(TLD) or .(tld) patterns with .com
      value = value.sub(/\.\(TLD\)/i, '.com')

      # Handle comma-separated values
      if value.include?(',')
        value.split(',')
      else
        [value]
      end
    end

    def self.normalize_bugcrowd(value)
      # Handle dash-separated descriptions (e.g., "example.com - Production")
      if value.include?(' - ')
        [value.split(' - ').first.strip]
      else
        [value]
      end
    end
  end
end
