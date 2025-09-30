# frozen_string_literal: true

module ScopesExtractor
  # Utility module for detecting scope categories based on URL patterns
  module ScopeCategoryDetector
    # Determines if a scope is a source code repository
    # @param scope [String] Scope value
    # @return [Boolean] True if the scope is from a source code platform
    def self.source_code?(scope)
      return false if scope.nil? || scope.empty?

      scope.start_with?('https://github.com/') ||
        scope.include?('marketplace.atlassian.com')
    end

    # Determines if a scope is a mobile application
    # @param scope [String] Scope value
    # @return [Boolean] True if the scope is from a mobile app store
    def self.mobile_app?(scope)
      return false if scope.nil? || scope.empty?

      scope.include?('play.google.com') ||
        scope.include?('itunes.apple.com') ||
        scope.include?('apps.apple.com')
    end

    # Determines if a scope should be categorized as "other"
    # @param scope [String] Scope value
    # @return [Boolean] True if the scope should be in the "other" category
    def self.other_category?(scope)
      return false if scope.nil? || scope.empty?

      scope.include?('chromewebstore.google.com')
    end

    # Adjusts the category based on scope URL patterns
    # @param category [Symbol] Current category
    # @param scope [String] Scope value
    # @return [Symbol] Adjusted category
    def self.adjust_category(category, scope)
      return category if scope.nil? || scope.empty?

      return :source_code if source_code?(scope)
      return :mobile if mobile_app?(scope)
      return :other if other_category?(scope)

      category
    end
  end
end
