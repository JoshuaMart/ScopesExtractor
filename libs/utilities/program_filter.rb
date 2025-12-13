# frozen_string_literal: true

require_relative '../platforms/config'

module ScopesExtractor
  # ProgramFilter module provides utilities for filtering excluded programs
  # based on platform-specific exclusion lists
  module ProgramFilter
    class << self
      # Checks if a program identifier is excluded for a specific platform
      # @param platform [String, Symbol] The platform name (bugcrowd, yeswehack, hackerone, intigriti, immunefi)
      # @param identifier [String] The program identifier (slug, handle, or ID depending on platform)
      # @return [Boolean] True if the program is excluded, false otherwise
      def excluded?(platform, identifier)
        exclusions = program_exclusions[platform] || []
        exclusions.include?(identifier)
      end

      private

      # Gets program exclusions from config
      # Uses memoization to avoid loading config multiple times
      # @return [Hash] Hash of platform-specific exclusion lists
      def program_exclusions
        @program_exclusions ||= Config.load[:parser][:program_exclusions]
      end
    end
  end
end
