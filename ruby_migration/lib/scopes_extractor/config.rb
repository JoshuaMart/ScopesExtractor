# frozen_string_literal: true

require 'yaml'

module ScopesExtractor
  class Config
    def self.load(path = 'config/settings.yml')
      @load ||= begin
        data = YAML.load_file(path)

        # Simple symbolization of keys
        deep_symbolize(data)
      end
    end

    def self.platforms
      load[:platforms] || {}
    end

    def self.sync
      load[:sync] || {}
    end

    def self.excluded?(platform, program_id)
      # Check platform specific exclusions
      platforms.dig(platform.to_sym, :exclusions)&.include?(program_id) || false
    end

    def self.deep_symbolize(hash)
      return hash unless hash.is_a?(Hash)

      hash.each_with_object({}) do |(k, v), result|
        result[k.to_sym] = v.is_a?(Hash) ? deep_symbolize(v) : v
      end
    end
  end
end
