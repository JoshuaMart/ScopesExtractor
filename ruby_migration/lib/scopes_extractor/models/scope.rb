# frozen_string_literal: true

module ScopesExtractor
  module Models
    class Scope < Dry::Struct
      attribute? :id, Types::Integer
      attribute :program_id, Types::String
      attribute :value, Types::String
      attribute :type, Types::String.enum('web', 'mobile', 'source_code', 'executable', 'cidr', 'other')
      attribute :is_in_scope, Types::Bool.default(true)
      attribute? :created_at, Types::DateTime

      def self.new(attributes)
        val = attributes[:value].to_s

        # Auto-heuristic: CIDR detection (e.g., 1.2.3.4/24)
        # Check for IP pattern + slash + digits
        if val.match?(%r{^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$})
          attributes = attributes.dup
          attributes[:type] = 'cidr'
        # Auto-heuristic: Source Code (GitHub, GitLab)
        elsif val.match?(%r{^https?://(www\.)?(github\.com|gitlab\.com)})
          attributes = attributes.dup
          attributes[:type] = 'source_code'
        # Auto-heuristic: Mobile App Store URLs
        elsif val.match?(%r{^https?://(apps\.apple\.com|itunes\.apple\.com|play\.google\.com)})
          attributes = attributes.dup
          attributes[:type] = 'mobile'
        # Auto-heuristic: Wildcard domain -> force type 'web'
        elsif val.start_with?('*.')
          attributes = attributes.dup
          attributes[:type] = 'web'
        end

        super(attributes)
      end
    end
  end
end
