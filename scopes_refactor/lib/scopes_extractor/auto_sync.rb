# frozen_string_literal: true

module ScopesExtractor
  # Background thread for automatic synchronization
  class AutoSync
    def initialize(sync_manager)
      @sync_manager = sync_manager
      @thread = nil
      @running = false
    end

    # Start the auto-sync background thread
    def start
      return if @running

      config = Config.sync
      return unless config[:auto]

      @running = true
      delay = config[:delay]

      ScopesExtractor.logger.info "Starting auto-sync with #{delay}s delay"

      # Perform initial sync immediately
      perform_sync

      @thread = Thread.new do
        loop do
          break unless @running

          sleep(delay)
          break unless @running

          perform_sync
        end
      end
    end

    # Stop the auto-sync background thread
    def stop
      return unless @running

      ScopesExtractor.logger.info 'Stopping auto-sync...'
      @running = false
      @thread&.join(5) # Wait up to 5 seconds for thread to finish
      @thread = nil
    end

    # Check if auto-sync is running
    def running?
      @running
    end

    private

    def perform_sync
      ScopesExtractor.logger.info '[AutoSync] Starting scheduled synchronization'
      @sync_manager.run
      ScopesExtractor.logger.info '[AutoSync] Scheduled synchronization completed'
    rescue StandardError => e
      ScopesExtractor.logger.error "[AutoSync] Sync failed: #{e.message}"
      ScopesExtractor.logger.debug e.backtrace.join("\n")
    end
  end
end
