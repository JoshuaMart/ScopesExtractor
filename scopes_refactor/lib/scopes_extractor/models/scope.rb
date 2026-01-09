# frozen_string_literal: true

require 'dry-struct'
require_relative 'types'

module ScopesExtractor
  module Models
    class Scope < Dry::Struct
      attribute :value, Types::String
      attribute :type, Types::String
      attribute :is_in_scope, Types::Bool

      def self.new(attributes)
        attrs = attributes.is_a?(Hash) ? normalize_keys(attributes) : attributes
        super(attrs)
      end

      def self.normalize_keys(hash)
        {
          value: hash[:value],
          type: hash[:type],
          is_in_scope: hash.key?(:is_in_scope) ? hash[:is_in_scope] : hash[:in_scope]
        }
      end

      def to_h
        {
          value: value,
          type: type,
          is_in_scope: is_in_scope
        }
      end

      def in_scope?
        is_in_scope
      end

      def out_scope?
        !is_in_scope
      end
    end
  end
end
