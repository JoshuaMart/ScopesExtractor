# frozen_string_literal: true

require 'ipaddr'
require 'uri'
require 'public_suffix'

module ScopesExtractor
  # Normalizer
  module Normalizer
    INVALID_CHARS = [',', '{', '<', '[', '(', ' ', '-*'].freeze

    def self.general(value)
        value = value.strip
        value = value.split(' ').first
        value = value[..-2] if value.end_with?('/*')
        value = value[..-2] if value.end_with?('/') && value.start_with?('*.')
        value = value[1..] if value.start_with?('*') && !value.start_with?('*.')
        value = value.sub(%r{https?://}, '') if value.match?(%r{https?://\*\.})
        value = value.sub('.*', '.com').sub('.<TLD>', '.com').sub(%r{/$}, '').sub(/\*$/, '').sub(/,$/, '')
        value = "*#{value}" if value.start_with?('.')

        value.downcase
    end

    def self.valid?(value)
      return false if (INVALID_CHARS.any? { |char| value.include?(char) } || !value.include?('.'))

      if value.match?(/\A((?:\d{1,3}\.){3}(?:\d{1,3})\Z)/)
        begin
          IPAddr.new(value)
          true
        rescue IPAddr::InvalidAddressError
          Utilities.log_warn("Bad IPAddr for #{value}")
          false
        end
      else
        begin
          host = value.start_with?('http') ? URI.parse(value)&.host : value
          domain = PublicSuffix.domain(host)

          if domain.nil?
            Utilities.log_warn("Nil domain for '#{host}")
            return false
          end

          true
        rescue URI::InvalidURIError
          Utilities.log_warn("Bad URI for '#{value}'.")
          false
        end
      end
    end
  end
end
