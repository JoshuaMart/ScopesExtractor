# frozen_string_literal: true

module ScopesExtractor
  module Platforms
    # Abstract base class for all platform implementations
    # Each platform must implement:
    # - name: Returns the platform name (e.g., "YesWeHack")
    # - fetch_programs: Returns an array of Models::Program instances
    class BasePlatform
      attr_reader :config

      def initialize(config = {})
        @config = config
      end

      # Returns the platform name
      # @return [String] the platform name
      def name
        raise NotImplementedError, "#{self.class} must implement #name"
      end

      # Fetches all programs from the platform
      # @return [Array<Models::Program>] array of program instances
      def fetch_programs
        raise NotImplementedError, "#{self.class} must implement #fetch_programs"
      end

      # Optional: Validates platform access/authentication
      # Platforms can override this to check credentials before fetching
      # @return [Boolean] true if access is valid, false otherwise
      def valid_access?
        true
      end
    end
  end
end
