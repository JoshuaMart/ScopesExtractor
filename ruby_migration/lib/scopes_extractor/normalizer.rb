# frozen_string_literal: true

module ScopesExtractor
  module Normalizer
    MULTI_TLDS_REGEX = %r{(?<prefix>https?://|wss?://|\*\.)?(?<middle>[\w.-]+\.)\((?<tlds>[a-z0-9.\\/|_-]+)\)}.freeze

    def self.normalize(platform, value)
      value = global_normalization(value)

      normalized = case platform.downcase
                   when 'yeswehack' then normalize_yeswehack(value)
                   when 'intigriti' then normalize_intigriti(value)
                   when 'hackerone' then normalize_hackerone(value)
                   when 'bugcrowd'  then normalize_bugcrowd(value)
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
      # Fix placeholders
      value = value.sub(/^\*(\s\.|\.?\s)/, '*.')
      value = value.gsub('.*', '.com')
      value = value.gsub(/\.<TLD>/i, '.com')

      value.include?(' / ') ? value.split(' / ') : [value]
    end

    def self.normalize_hackerone(value)
      value = value.gsub('.*', '.com')
      value = value.gsub(/\.\(TLD\)/i, '.com')

      value.include?(',') ? value.split(',') : [value]
    end

    def self.normalize_bugcrowd(value)
      value.include?(' - ') ? [value.split(' - ').first.strip] : [value]
    end
  end
end
