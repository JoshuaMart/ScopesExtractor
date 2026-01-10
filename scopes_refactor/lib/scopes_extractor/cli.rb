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
    end

    desc 'sync [PLATFORM]', 'Synchronize programs from bug bounty platforms'
    option :verbose, type: :boolean, aliases: '-v', desc: 'Enable verbose logging'
    def sync(platform = nil)
      setup_logging(options[:verbose])

      Database.connect
      Database.migrate

      sync_manager = SyncManager.new
      sync_manager.run(platform_name: platform)
    rescue StandardError => e
      ScopesExtractor.logger.error "Sync failed: #{e.message}"
      ScopesExtractor.logger.debug e.backtrace.join("\n") if options[:verbose]
      exit 1
    end

    desc 'serve', 'Start the API server'
    option :port, type: :numeric, aliases: '-p', desc: 'Port to bind to'
    option :bind, type: :string, aliases: '-b', desc: 'Address to bind to'
    option :sync, type: :boolean, aliases: '-s', desc: 'Enable auto-sync in background'
    option :verbose, type: :boolean, aliases: '-v', desc: 'Enable verbose logging'
    def serve
      setup_logging(options[:verbose])
      prepare_database

      auto_sync = setup_auto_sync if options[:sync]
      configure_and_start_server(auto_sync)
    rescue StandardError => e
      handle_server_error(e, auto_sync)
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

    def prepare_database
      Database.connect
      Database.migrate
    end

    def setup_auto_sync
      sync_manager = SyncManager.new
      auto_sync = AutoSync.new(sync_manager)
      auto_sync.start
      auto_sync
    end

    def configure_and_start_server(auto_sync)
      port = options[:port] || Config.api_port
      bind = options[:bind] || Config.api_bind

      API.set :port, port
      API.set :bind, bind

      ScopesExtractor.logger.info "Starting API server on #{bind}:#{port}"

      setup_shutdown_handler(auto_sync)
      API.run!
    end

    def setup_shutdown_handler(auto_sync)
      trap('INT') do
        ScopesExtractor.logger.info "\nShutting down gracefully..."
        auto_sync&.stop
        exit
      end
    end

    def handle_server_error(error, auto_sync)
      ScopesExtractor.logger.error "Server failed: #{error.message}"
      ScopesExtractor.logger.debug error.backtrace.join("\n") if options[:verbose]
      auto_sync&.stop
      exit 1
    end
  end
end
