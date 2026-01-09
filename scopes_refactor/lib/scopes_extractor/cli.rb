# frozen_string_literal: true

require 'thor'

module ScopesExtractor
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc 'version', 'Display version information'
    def version
      puts 'ScopesExtractor version 2.0.0'
    end

    desc 'reset', 'Reset the database (WARNING: deletes all data)'
    option :force, type: :boolean, aliases: '-f', desc: 'Skip confirmation prompt'
    def reset
      unless options[:force]
        print 'This will delete ALL data from the database. Are you sure? (y/N) '
        confirmation = $stdin.gets.chomp
        return unless confirmation.downcase == 'y'
      end

      ScopesExtractor.logger.info 'Resetting database...'
      Database.connect
      Database.reset
      ScopesExtractor.logger.info 'Database reset complete'
    end

    desc 'sync [PLATFORM]', 'Synchronize programs from bug bounty platforms'
    option :verbose, type: :boolean, aliases: '-v', desc: 'Enable verbose logging'
    def sync(platform = nil)
      setup_logging(options[:verbose])

      if platform
        ScopesExtractor.logger.info "Starting sync for platform: #{platform}"
      else
        ScopesExtractor.logger.info 'Starting sync for all enabled platforms'
      end

      # TODO: Implement in Phase 6 with SyncManager
      ScopesExtractor.logger.warn 'Sync functionality not yet implemented (Phase 6)'
    end

    desc 'serve', 'Start the API server'
    option :port, type: :numeric, aliases: '-p', desc: 'Port to bind to'
    option :bind, type: :string, aliases: '-b', desc: 'Address to bind to'
    option :sync, type: :boolean, aliases: '-s', desc: 'Enable auto-sync in background'
    option :verbose, type: :boolean, aliases: '-v', desc: 'Enable verbose logging'
    def serve
      setup_logging(options[:verbose])

      port = options[:port] || Config.api_port
      bind = options[:bind] || Config.api_bind

      ScopesExtractor.logger.info "Starting API server on #{bind}:#{port}"

      if options[:sync]
        ScopesExtractor.logger.info 'Auto-sync enabled'
        # TODO: Start background sync thread (Phase 8.2)
      end

      # TODO: Implement in Phase 7 with Sinatra
      ScopesExtractor.logger.warn 'API server functionality not yet implemented (Phase 7)'
    end

    desc 'migrate', 'Run database migrations'
    def migrate
      ScopesExtractor.logger.info 'Running database migrations...'
      Database.connect
      Database.migrate
      ScopesExtractor.logger.info 'Migrations complete'
    end

    desc 'cleanup', 'Cleanup old history entries'
    def cleanup
      ScopesExtractor.logger.info 'Cleaning up old history entries...'
      Database.connect
      Database.cleanup_old_history
      ScopesExtractor.logger.info 'Cleanup complete'
    end

    private

    def setup_logging(verbose)
      return unless verbose

      ScopesExtractor.logger.level = Logger::DEBUG
      ScopesExtractor.logger.debug 'Verbose logging enabled'
    end
  end
end
