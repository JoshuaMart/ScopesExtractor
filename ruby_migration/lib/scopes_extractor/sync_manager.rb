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

      # Cleanup old history before sync
      Database.cleanup_old_history

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
      platform_key = platform.name.downcase

      db_programs = ScopesExtractor.db[:programs].where(platform: platform_key).all
      fetched_slugs = extract_fetched_slugs(platform_key, programs)

      sync_fetched_programs(platform, platform_key, programs, engine)
      handle_removed_programs(platform, platform_key, db_programs, fetched_slugs)
    end

    def extract_fetched_slugs(platform_key, programs)
      programs.reject { |p| Config.excluded?(platform_key, p.slug) }
              .map(&:slug)
    end

    def sync_fetched_programs(platform, platform_key, programs, engine)
      programs.each do |prog|
        next if skip_excluded_program?(platform, platform_key, prog)

        engine.process_program(platform_key, prog)
      rescue StandardError => e
        handle_program_sync_error(platform, prog, e)
      end
    end

    def skip_excluded_program?(platform, platform_key, prog)
      return false unless Config.excluded?(platform_key, prog.slug)

      ScopesExtractor.logger.debug "[#{platform.name}] Skipping excluded program: #{prog.slug}"
      true
    end

    def handle_program_sync_error(platform, prog, error)
      error_msg = "Failed to process program #{prog.slug} on #{platform.name}: #{error.message}"
      ScopesExtractor.logger.error "[#{platform.name}] #{error_msg}"
      ScopesExtractor.notifier.log('Program Sync Error', error_msg, level: :error)
    end

    def handle_removed_programs(platform, platform_key, db_programs, fetched_slugs)
      db_slugs = db_programs.map { |p| p[:slug] }
      removed_slugs = db_slugs - fetched_slugs

      removed_slugs.each do |slug|
        program = db_programs.find { |p| p[:slug] == slug }
        next unless program

        remove_program(platform, platform_key, program)
      end
    end

    def remove_program(platform, platform_key, program)
      scopes_json = collect_program_scopes(program[:id])

      log_program_removal(program, platform_key, scopes_json)
      delete_program_from_db(program[:id])
      notify_program_removal(platform, platform_key, program)
    end

    def collect_program_scopes(program_id)
      scopes = ScopesExtractor.db[:scopes].where(program_id: program_id).all
      scopes_data = { in: {}, out: {} }

      scopes.each do |scope|
        category = scope[:is_in_scope] ? :in : :out
        type = scope[:type]
        scopes_data[category][type] ||= []
        scopes_data[category][type] << scope[:value]
      end

      scopes_data.to_json
    end

    def log_program_removal(program, platform_key, scopes_json)
      ScopesExtractor.db[:history].insert(
        program_id: program[:id],
        platform_name: platform_key,
        program_name: program[:name],
        event_type: 'remove_program',
        details: scopes_json,
        created_at: Time.now
      )
    end

    def delete_program_from_db(program_id)
      ScopesExtractor.db[:programs].where(id: program_id).delete
    end

    def notify_program_removal(platform, platform_key, program)
      ScopesExtractor.notifier.notify_removed_program(platform_key, program[:name], program[:slug])
      ScopesExtractor.logger.info "[#{platform.name}] Removed program: #{program[:name]} (#{program[:slug]})"
    end
  end
end
