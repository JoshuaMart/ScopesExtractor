# frozen_string_literal: true

module ScopesExtractor
  module Models
    class Scope < Dry::Struct
      attribute? :id, Types::Integer
      attribute :program_id, Types::String
      attribute :value, Types::String
      attribute :type, Types::String.enum('web', 'mobile', 'api', 'source_code', 'executable', 'other')
      attribute :is_in_scope, Types::Bool.default(true)
      attribute? :created_at, Types::DateTime

      def self.new(attributes)
        # Auto-heuristic: If it looks like a wildcard domain, force type to 'web'
        if attributes[:value].to_s.start_with?('*.')
          attributes = attributes.dup # Avoid mutating original hash
          attributes[:type] = 'web'
        end

        super(attributes)
      end
    end
  end
end
