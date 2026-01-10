# frozen_string_literal: true

module ScopesExtractor
  module Normalizer
    MULTI_TLDS_REGEX = %r{(?<prefix>https?://|wss?://|\*\.)?(?<middle>[\w.-]+\.)\((?<tlds>[a-z0-9.\\/|_-]+)\)}

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
      value = value.to_s.strip

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
      if (match = value.match(MULTI_TLDS_REGEX))
        prefix = match[:prefix] || ''
        middle = match[:middle]
        tlds = match[:tlds].split('|')
        tlds.map { |tld| "#{prefix}#{middle}#{tld}" }
      else
        [value]
      end
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
