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
        attrs = normalize_and_refine(attributes)
        super(attrs)
      end

      # Normalize keys and apply auto-heuristic type detection
      def self.normalize_and_refine(attributes)
        return attributes unless attributes.is_a?(Hash)

        # Step 1: Normalize keys
        normalized = {
          value: attributes[:value],
          type: attributes[:type],
          is_in_scope: attributes.key?(:is_in_scope) ? attributes[:is_in_scope] : attributes[:in_scope]
        }

        # Step 2: Auto-heuristic type detection (overrides platform type when matched)
        value = normalized[:value].to_s

        # CIDR detection (e.g., 1.2.3.4/24)
        if value.match?(%r{^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$})
          normalized[:type] = 'cidr'
        # Source Code (GitHub, GitLab, Atlassian Marketplace)
        elsif value.match?(%r{^https?://((www\.)?(github|gitlab)\.com|marketplace\.atlassian\.com)})
          normalized[:type] = 'source_code'
        # Mobile App Store URLs
        elsif value.match?(%r{^https?://(apps\.apple\.com|itunes\.apple\.com|play\.google\.com)})
          normalized[:type] = 'mobile'
        # Chrome Web Store (Extensions)
        elsif value.match?(%r{^https?://(chrome\.google\.com/webstore|chromewebstore\.google\.com)})
          normalized[:type] = 'executable'
        # Wildcard domain -> force type 'web'
        elsif value.start_with?('*.')
          normalized[:type] = 'web'
        end
        # Otherwise keep the type provided by the platform

        normalized
      end

      private_class_method :normalize_and_refine

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
