# frozen_string_literal: true

require 'concurrent-ruby'

module ScopesExtractor
  class SyncManager
    def initialize
      @platforms = []
      setup_platforms
    end

    def run(platform_name: nil)
      targets = if platform_name
                  @platforms.select do |p|
                    p.name.downcase.gsub('_', '') == platform_name.downcase.gsub('_', '')
                  end
                else
                  @platforms
                end

      if targets.empty?
        ScopesExtractor.logger.warn "No enabled platforms matching '#{platform_name}'"
        return
      end

      ScopesExtractor.logger.info "Starting global synchronization for #{targets.size} platforms"

      # Use Concurrent::Promises for parallel execution
      promises = targets.map do |platform|
        Concurrent::Promises.future(platform) do |p|
          sync_platform(p)
        end
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
      end
    end

    def sync_platform(platform)
      ScopesExtractor.logger.info "[#{platform.name}] Syncing..."
      programs = platform.fetch_programs

      engine = DiffEngine.new
      programs.each do |prog|
        # Skip if program is globally excluded
        if Config.excluded?(platform.name.downcase, prog.id)
          ScopesExtractor.logger.debug "[#{platform.name}] Skipping excluded program: #{prog.id}"
          next
        end

        engine.process_program(platform.name.downcase, prog)
      rescue StandardError => e
        error_msg = "Failed to process program #{prog.id} on #{platform.name}: #{e.message}"
        ScopesExtractor.logger.error "[#{platform.name}] #{error_msg}"
        ScopesExtractor.notifier.log('Program Sync Error', error_msg, level: :error)
      end

      ScopesExtractor.logger.info "[#{platform.name}] Sync completed. Processed #{programs.size} programs."
    rescue StandardError => e
      ScopesExtractor.logger.error "[#{platform.name}] Sync failed: #{e.message}"
      ScopesExtractor.notifier.log('Sync Error', "Platform #{platform.name} failed: #{e.message}", level: :error)
    end
  end
end
