# frozen_string_literal: true

require 'json'
require 'rotp'
require 'logger'

Dir[File.join(__dir__, 'platforms', '**', '*.rb')].sort.each { |file| require file }
Dir[File.join(__dir__, 'utilities', '**', '*.rb')].sort.each { |file| require file }
Dir[File.join(__dir__, 'db', '*.rb')].sort.each { |file| require file }

module ScopesExtractor
  # The Extract class manages the process of extracting and comparing bug bounty program scopes
  # from multiple platforms, handling notifications when changes are detected.
  class Extract
    # List of supported bug bounty platforms
    PLATFORMS = %w[Immunefi YesWeHack].freeze

    attr_accessor :config, :results

    # Initialize the extractor with configuration and empty results
    # @return [Extract] A new instance of the Extract class
    def initialize
      @config = Config.load
      @results = {}
      PLATFORMS.each { |platform| @results[platform] = {} }
    end

    # Run the extraction process for all platforms and handle notifications
    # @return [void]
    def run
      sync_platforms

      return unless api_mode?

      require 'webrick'

      server = WEBrick::HTTPServer.new(Port: 4567)
      server.mount_proc '/' do |req, res|
        api_response(req, res)
      end

      trap('INT') { server.shutdown }
      server.start
    end

    private

    # Processes an API request by verifying the API key in the header and returning the current data in JSON.
    #
    # @param req [WEBrick::HTTPRequest] The incoming HTTP request object.
    # @param res [WEBrick::HTTPResponse] The HTTP response object that will be returned.
    # @return [void]
    def api_response(req, res)
      api_key = req.header['x-api-key']&.first
      res.content_type = 'application/json'

      if api_key == config.dig(:api, :key)
        res.body = DB.load.to_json
      else
        res.status = 401
        res.body = { error: 'Unauthorized' }.to_json
      end
    end

    # Synchronizes the bug bounty platforms.
    #
    # If auto-sync is enabled in the configuration, this method spawns a new thread that
    # repeatedly performs synchronization with a configurable delay.
    # Otherwise, it performs a one-time synchronization.
    #
    # @return [Thread, void] Returns a Thread object if auto-sync is enabled, or nil if running synchronously.
    def sync_platforms
      Utilities.log_warn("AutoSync Status : #{auto_sync?}")
      if auto_sync?
        Thread.new do
          loop do
            perform_sync
            delay = config.dig(:sync, :delay)&.to_i
            Utilities.log_info("Sleep #{delay}")
            sleep(delay)
          end
        end
      else
        api_mode? ? Thread.new { perform_sync } : perform_sync
      end
    end

    # Performs the synchronization of platforms.
    #
    # This method loads the current data from the database, runs the platform-specific sync methods,
    # compares the newly fetched data with the existing data to trigger notifications, and finally saves
    # the updated results back to the database.
    #
    # @return [void]
    def perform_sync
      Utilities.log_info('Start synchronisation')
      current_data = DB.load

      yeswehack_sync
      immunefi_sync

      compare_and_notify(current_data, results) unless current_data.empty?

      DB.save(results)
      Utilities.log_info('Synchronisation Finished')
    end

    # Determines whether API mode is enabled in the configuration.
    #
    # @return [Boolean] Returns true if API mode is enabled, false otherwise.
    def api_mode?
      config.dig(:api, :enabled)&.downcase == 'true'
    end

    # Determines whether auto synchronization is enabled in the configuration.
    #
    # @return [Boolean] Returns true if auto-sync is enabled, false otherwise.
    def auto_sync?
      config.dig(:sync, :auto)&.downcase == 'true'
    end

    # Compares old and new data, and triggers notifications for changes
    # @param old_data [Hash] Previous program scope data
    # @param new_data [Hash] Current program scope data
    # @return [void]
    def compare_and_notify(old_data, new_data)
      parsed_new_data = Parser.json_parse(JSON.generate(new_data))
      PLATFORMS.each do |platform|
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
    def process_existing_and_new_programs(old_programs, new_programs, platform)
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
    def process_removed_programs(old_programs, new_programs, platform)
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
    def compare_scopes(new_scopes, old_scopes, program_title, platform)
      %w[in out].each do |scope_type|
        new_scope_groups = new_scopes[scope_type] || {}
        old_scope_groups = old_scopes[scope_type] || {}

        compare_new_scopes(new_scope_groups, old_scope_groups, program_title, platform, scope_type)
        compare_old_scopes(new_scope_groups, old_scope_groups, program_title, platform, scope_type)
      end
    end

    # Compares new scopes with old ones to detect additions
    # @param new_scope_groups [Hash] Current scope groups
    # @param old_scope_groups [Hash] Previous scope groups
    # @param program_title [String] Program title
    # @param platform [String] The platform name
    # @param scope_type [String] Scope type ('in' or 'out')
    # @return [void]
    def compare_new_scopes(new_scope_groups, old_scope_groups, program_title, platform, scope_type)
      new_scope_groups.each do |category, scopes_array|
        scopes_array.each do |scope|
          unless old_scope_groups[category]&.include?(scope)
            Discord.new_scope(platform, program_title, scope, category, scope_type == 'in')
          end
        end
      end
    end

    # Compares old scopes with new ones to detect removals
    # @param new_scope_groups [Hash] Current scope groups
    # @param old_scope_groups [Hash] Previous scope groups
    # @param program_title [String] Program title
    # @param platform [String] The platform name
    # @param scope_type [String] Scope type ('in' or 'out')
    # @return [void]
    def compare_old_scopes(new_scope_groups, old_scope_groups, program_title, platform, scope_type)
      old_scope_groups.each do |category, scopes_array|
        scopes_array.each do |scope|
          unless new_scope_groups[category]&.include?(scope)
            Discord.removed_scope(platform, program_title, scope, category, scope_type == 'in')
          end
        end
      end
    end

    # Checks if YesWeHack is configured with required credentials
    # @return [Boolean] True if YesWeHack is configured, false otherwise
    def yeswehack_configured?
      config.dig(:yeswehack, :email) && config.dig(:yeswehack, :password) && config.dig(:yeswehack, :otp)
    end

    # Syncs data from YesWeHack platform
    # @return [void]
    def yeswehack_sync
      return unless yeswehack_configured?

      jwt = YesWeHack.authenticate(config[:yeswehack])
      Discord.log_warn('YesWeHack - Authentication Failed') unless jwt

      config[:yeswehack][:headers] = { 'Content-Type' => 'application/json', Authorization: "Bearer #{jwt}" }
      YesWeHack::Programs.sync(results['YesWeHack'], config[:yeswehack]) if jwt
    end

    # Syncs data from Immunefi platform
    # @return [void]
    def immunefi_sync
      # Immunefi::Programs.sync(results['Immunefi'])
    end
  end
end
