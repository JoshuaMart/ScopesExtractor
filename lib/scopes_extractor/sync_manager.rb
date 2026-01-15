# frozen_string_literal: true

require 'concurrent-ruby'

module ScopesExtractor
  class SyncManager
    def initialize(diff_engine: nil, notifier: nil)
      @diff_engine = diff_engine || DiffEngine.new(notifier: notifier)
      @notifier = notifier || Notifiers::Discord.new
      @platforms = []
      @db = ScopesExtractor.db
      setup_platforms
    end

    def run(platform_name: nil)
      targets = targets_for(platform_name)

      if targets.empty?
        ScopesExtractor.logger.warn "No enabled platforms matching '#{platform_name}'"
        return
      end

      execute_sync(targets)
    end

    def targets_for(platform_name)
      if platform_name
        @platforms.select do |p|
          p.name.downcase.delete('_') == platform_name.downcase.delete('_')
        end
      else
        @platforms
      end
    end

    private

    def execute_sync(targets)
      ScopesExtractor.logger.info "Starting synchronization for #{targets.size} platform(s)"

      # Cleanup old history before sync
      Database.cleanup_old_history

      # Use Concurrent::Promises for parallel execution
      promises = targets.map do |platform|
        Concurrent::Promises.future(platform) { |p| sync_platform(p) }
      end

      # Wait for all syncing to complete
      Concurrent::Promises.zip(*promises).value
      ScopesExtractor.logger.info 'Synchronization completed'
    end

    def setup_platforms
      config = Config.platforms

      # YesWeHack
      if config.dig(:yeswehack, :enabled)
        @platforms << Platforms::YesWeHack::Platform.new(
          email: ENV.fetch('YWH_EMAIL', nil),
          password: ENV.fetch('YWH_PWD', nil),
          otp: ENV.fetch('YWH_OTP', nil)
        )
      end

      # Intigriti
      if config.dig(:intigriti, :enabled)
        @platforms << Platforms::Intigriti::Platform.new(
          token: ENV.fetch('INTIGRITI_TOKEN', nil)
        )
      end

      # HackerOne
      if config.dig(:hackerone, :enabled)
        @platforms << Platforms::HackerOne::Platform.new(
          username: ENV.fetch('H1_USERNAME', nil),
          api_token: ENV.fetch('H1_TOKEN', nil)
        )
      end

      # Bugcrowd
      return unless config.dig(:bugcrowd, :enabled)

      @platforms << Platforms::Bugcrowd::Platform.new(
        email: ENV.fetch('BUGCROWD_EMAIL', nil),
        password: ENV.fetch('BUGCROWD_PASSWORD', nil),
        otp_secret: ENV.fetch('BUGCROWD_OTP', nil)
      )

      # TODO: Add other platforms when implemented
      # @platforms << Platforms::Immunefi::Platform.new if config.dig(:immunefi, :enabled)
    end

    def sync_platform(platform)
      platform_key = platform.name.downcase
      ScopesExtractor.logger.info "[#{platform.name}] Starting sync..."

      # Validate access before fetching programs
      unless platform.valid_access?
        error_msg = 'Access validation failed - credentials may be invalid or expired'
        ScopesExtractor.logger.error "[#{platform.name}] #{error_msg}"
        @notifier.notify_error('Platform Access Error', "#{platform.name}: #{error_msg}")
        return nil
      end

      # Check if this is the first sync for this platform (DB is empty)
      is_first_sync = @db[:programs].where(platform: platform_key).none?

      if is_first_sync
        ScopesExtractor.logger.info "[#{platform.name}] First sync detected - notifications will be skipped"
      end

      programs = platform.fetch_programs

      # Skip processing if fetch failed (exception was raised and caught)
      return unless programs

      process_programs(platform_key, programs, skip_notifications: is_first_sync)

      ScopesExtractor.logger.info "[#{platform.name}] Sync completed. Processed #{programs.size} program(s)."
    rescue StandardError => e
      handle_sync_error(platform.name, e)
      # Return nil to indicate sync failure - prevents processing with empty data
      nil
    end

    def process_programs(platform_key, programs, skip_notifications: false)
      # Extract fetched slugs for removed program detection
      fetched_slugs = programs.reject { |p| Config.excluded?(platform_key, p.slug) }
                              .map(&:slug)

      # Process each fetched program
      programs.each do |program|
        next if skip_excluded_program?(platform_key, program)

        @diff_engine.process_program(platform_key, program, skip_notifications: skip_notifications)
      rescue StandardError => e
        handle_program_error(platform_key, program, e)
      end

      # Handle removed programs (skip notifications on first sync)
      @diff_engine.process_removed_programs(platform_key, fetched_slugs, skip_notifications: skip_notifications)
    end

    def skip_excluded_program?(platform_key, program)
      return false unless Config.excluded?(platform_key, program.slug)

      ScopesExtractor.logger.debug "[#{platform_key}] Skipping excluded program: #{program.slug}"
      true
    end

    def handle_program_error(platform_key, program, error)
      error_msg = "Failed to process program #{program.slug}: #{error.message}"
      ScopesExtractor.logger.error "[#{platform_key}] #{error_msg}"
      @notifier.notify_error('Program Sync Error', error_msg)
    end

    def handle_sync_error(platform_name, error)
      error_msg = "Sync failed: #{error.message}"
      ScopesExtractor.logger.error "[#{platform_name}] #{error_msg}"
      @notifier.notify_error('Platform Sync Error', "#{platform_name}: #{error_msg}")
    end
  end
end
