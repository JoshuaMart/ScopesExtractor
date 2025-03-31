# frozen_string_literal: true

module ScopesExtractor
  module Utilities
    # The ScopeComparator module provides functionality for comparing bug bounty program scopes
    # and detecting changes (additions and removals) between program versions
    module ScopeComparator
      # Compares old and new data, and triggers notifications for changes
      # @param old_data [Hash] Previous program scope data
      # @param new_data [Hash] Current program scope data
      # @param platforms [Array<String>] List of platforms to compare
      # @return [void]
      def self.compare_and_notify(old_data, new_data, platforms)
        parsed_new_data = Parser.json_parse(JSON.generate(new_data))
        platforms.each do |platform|
          old_programs = old_data[platform] || {}
          next if old_programs.empty?

          new_programs = parsed_new_data[platform] || {}

          process_existing_and_new_programs(old_programs, new_programs, platform)
          process_removed_programs(old_programs, new_programs, platform)
        end
      end

      # Processes existing and new programs to detect changes and additions
      # @param old_programs [Hash] Previous program data
      # @param new_programs [Hash] Current program data
      # @param platform [String] The platform name
      # @return [void]
      def self.process_existing_and_new_programs(old_programs, new_programs, platform)
        new_programs.each do |title, info|
          if old_programs.key?(title)
            # For existing programs, compare scopes
            old_scopes = old_programs[title]['scopes'] || {}
            new_scopes = info['scopes'] || {}
            compare_scopes(new_scopes, old_scopes, title, platform)
          else
            Discord.new_program(platform, title, info['slug'], info['private'])
          end
        end
      end

      # Processes removed programs to detect deletions
      # @param old_programs [Hash] Previous program data
      # @param new_programs [Hash] Current program data
      # @param platform [String] The platform name
      # @return [void]
      def self.process_removed_programs(old_programs, new_programs, platform)
        old_programs.each_key do |title|
          Discord.removed_program(platform, title) unless new_programs.key?(title)
        end
      end

      # Compares program scopes (in and out of scope) and notifies additions and deletions
      # @param new_scopes [Hash] Current program scope data
      # @param old_scopes [Hash] Previous program scope data
      # @param program_title [String] Program title
      # @param platform [String] The platform name
      # @return [void]
      def self.compare_scopes(new_scopes, old_scopes, program_title, platform)
        %w[in out].each do |scope_type|
          new_scope_groups = new_scopes[scope_type] || {}
          old_scope_groups = old_scopes[scope_type] || {}

          context = ScopeContext.new(program_title, platform, scope_type)
          detect_added_scopes(new_scope_groups, old_scope_groups, context)
          detect_removed_scopes(new_scope_groups, old_scope_groups, context)
        end
      end

      # Detects scopes that have been added
      # @param new_scope_groups [Hash] Current scope groups
      # @param old_scope_groups [Hash] Previous scope groups
      # @param context [ScopeContext] Context object containing program information
      # @return [void]
      def self.detect_added_scopes(new_scope_groups, old_scope_groups, context)
        new_scope_groups.each do |category, scopes_array|
          scopes_array.each do |scope|
            unless old_scope_groups[category]&.include?(scope)
              Discord.new_scope(context.platform, context.program_title, scope, category, context.in_scope?)
            end
          end
        end
      end

      # Detects scopes that have been removed
      # @param new_scope_groups [Hash] Current scope groups
      # @param old_scope_groups [Hash] Previous scope groups
      # @param context [ScopeContext] Context object containing program information
      # @return [void]
      def self.detect_removed_scopes(new_scope_groups, old_scope_groups, context)
        old_scope_groups.each do |category, scopes_array|
          scopes_array.each do |scope|
            unless new_scope_groups[category]&.include?(scope)
              Discord.removed_scope(context.platform, context.program_title, scope, category, context.in_scope?)
            end
          end
        end
      end

      # ScopeContext encapsulates context information needed for scope comparison operations
      # @attr_reader program_title [String] The title of the program
      # @attr_reader platform [String] The platform name
      # @attr_reader scope_type [String] The scope type ('in' or 'out')
      class ScopeContext
        attr_reader :program_title, :platform, :scope_type

        # Initializes a new ScopeContext instance
        # @param program_title [String] The title of the program
        # @param platform [String] The platform name
        # @param scope_type [String] The scope type ('in' or 'out')
        def initialize(program_title, platform, scope_type)
          @program_title = program_title
          @platform = platform
          @scope_type = scope_type
        end

        # Determines if the context represents an in-scope item
        # @return [Boolean] true if in scope, false otherwise
        def in_scope?
          scope_type == 'in'
        end
      end
    end
  end
end
