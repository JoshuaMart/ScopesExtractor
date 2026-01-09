# frozen_string_literal: true

require 'concurrent-ruby'

module ScopesExtractor
  class SyncManager
    def initialize(diff_engine: nil, notifier: nil)
      @diff_engine = diff_engine || DiffEngine.new(notifier: notifier)
      @notifier = notifier || Notifiers::Discord.new
      @platforms = []
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

      # TODO: Add other platforms when implemented
      # @platforms << Platforms::HackerOne::Platform.new if config.dig(:hackerone, :enabled)
      # @platforms << Platforms::Intigriti::Platform.new if config.dig(:intigriti, :enabled)
      # @platforms << Platforms::Bugcrowd::Platform.new if config.dig(:bugcrowd, :enabled)
      # @platforms << Platforms::Immunefi::Platform.new if config.dig(:immunefi, :enabled)
    end

    def sync_platform(platform)
      platform_key = platform.name.downcase
      ScopesExtractor.logger.info "[#{platform.name}] Starting sync..."

      programs = platform.fetch_programs
      process_programs(platform_key, programs)

      ScopesExtractor.logger.info "[#{platform.name}] Sync completed. Processed #{programs.size} program(s)."
    rescue StandardError => e
      handle_sync_error(platform.name, e)
    end

    def process_programs(platform_key, programs)
      # Extract fetched slugs for removed program detection
      fetched_slugs = programs.reject { |p| Config.excluded?(platform_key, p.slug) }
                              .map(&:slug)

      # Process each fetched program
      programs.each do |program|
        next if skip_excluded_program?(platform_key, program)

        @diff_engine.process_program(platform_key, program)
      rescue StandardError => e
        handle_program_error(platform_key, program, e)
      end

      # Handle removed programs
      @diff_engine.process_removed_programs(platform_key, fetched_slugs)
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
