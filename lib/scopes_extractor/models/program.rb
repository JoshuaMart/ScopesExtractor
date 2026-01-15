# frozen_string_literal: true

require 'dry-struct'
require_relative 'types'
require_relative 'scope'

module ScopesExtractor
  module Models
    class Program < Dry::Struct
      attribute? :id, Types::Integer.optional
      attribute :slug, Types::String
      attribute :platform, Types::String
      attribute :name, Types::String
      attribute :bounty, Types::Bool
      attribute :scopes, Types::Array.of(Scope).default([].freeze)

      def in_scopes
        scopes.select(&:is_in_scope)
      end

      def out_scopes
        scopes.reject(&:is_in_scope)
      end

      def to_h
        {
          id: id,
          slug: slug,
          platform: platform,
          name: name,
          bounty: bounty,
          scopes: scopes.map(&:to_h)
        }
      end
    end
  end
end
