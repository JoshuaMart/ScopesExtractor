# frozen_string_literal: true

module ScopesExtractor
  module Models
    class Program < Dry::Struct
      attribute? :id, Types::Integer # Auto-increment primary key (optional for new records)
      attribute :slug, Types::String # Platform-specific identifier (handle/slug)
      attribute :platform, Types::String
      attribute :name, Types::String
      attribute :bounty, Types::Bool.default(true)
      attribute? :last_updated, Types::DateTime
      attribute(:scopes, Types::Array.of(Models::Scope).default { [] })
    end
  end
end
