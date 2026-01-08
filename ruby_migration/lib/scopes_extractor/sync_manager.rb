# frozen_string_literal: true

require 'concurrent-ruby'

module ScopesExtractor
  class SyncManager
    def initialize
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

    def execute_sync(targets)
      ScopesExtractor.logger.info "Starting global synchronization for #{targets.size} platforms"

      # Use Concurrent::Promises for parallel execution
      promises = targets.map do |platform|
        Concurrent::Promises.future(platform) { |p| sync_platform(p) }
      end

      # Wait for all syncing to complete
      Concurrent::Promises.zip(*promises).value
      ScopesExtractor.logger.info 'Global synchronization completed'
    end

    private

    def setup_platforms
      config = Config.platforms

      @platforms << Platforms::YesWeHack::Platform.new(config_for(:ywh)) if config.dig(:yeswehack, :enabled)
      @platforms << Platforms::HackerOne::Platform.new(config_for(:h1)) if config.dig(:hackerone, :enabled)
      @platforms << Platforms::Intigriti::Platform.new(config_for(:intigriti)) if config.dig(:intigriti, :enabled)
      @platforms << Platforms::Bugcrowd::Platform.new(config_for(:bugcrowd)) if config.dig(:bugcrowd, :enabled)
      @platforms << Platforms::Immunefi::Platform.new(config_for(:immunefi)) if config.dig(:immunefi, :enabled)
    end

    def config_for(key)
      case key
      when :ywh
        { email: ENV.fetch('YWH_EMAIL', nil), password: ENV.fetch('YWH_PWD', nil), otp: ENV.fetch('YWH_OTP', nil) }
      when :h1
        { username: ENV.fetch('H1_USERNAME', nil), token: ENV.fetch('H1_TOKEN', nil) }
      when :intigriti
        { token: ENV.fetch('INTIGRITI_TOKEN', nil) }
      when :bugcrowd
        { email: ENV.fetch('BC_EMAIL', nil), password: ENV.fetch('BC_PWD', nil), otp: ENV.fetch('BC_OTP', nil) }
      when :immunefi
        {} # No auth required
      end
    end

    def sync_platform(platform)
      ScopesExtractor.logger.info "[#{platform.name}] Syncing..."
      programs = platform.fetch_programs

      process_programs(platform, programs)

      ScopesExtractor.logger.info "[#{platform.name}] Sync completed. Processed #{programs.size} programs."
    rescue StandardError => e
      ScopesExtractor.logger.error "[#{platform.name}] Sync failed: #{e.message}"
      ScopesExtractor.notifier.log('Sync Error', "Platform #{platform.name} failed: #{e.message}", level: :error)
    end

    def process_programs(platform, programs)
      engine = DiffEngine.new
      programs.each do |prog|
        # Skip if program is excluded
        if Config.excluded?(platform.name.downcase, prog.slug)
          ScopesExtractor.logger.debug "[#{platform.name}] Skipping excluded program: #{prog.slug}"
          next
        end

        engine.process_program(platform.name.downcase, prog)
      rescue StandardError => e
        error_msg = "Failed to process program #{prog.id} on #{platform.name}: #{e.message}"
        ScopesExtractor.logger.error "[#{platform.name}] #{error_msg}"
        ScopesExtractor.notifier.log('Program Sync Error', error_msg, level: :error)
      end
    end
  end
end
