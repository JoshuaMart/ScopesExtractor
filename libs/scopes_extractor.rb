# frozen_string_literal: true

require 'json'
require 'rotp'
require 'logger'
require 'base64'

Dir[File.join(__dir__, 'platforms', '**', '*.rb')].sort.each { |file| require file }
Dir[File.join(__dir__, 'utilities', '**', '*.rb')].sort.each { |file| require file }
Dir[File.join(__dir__, 'db', '*.rb')].sort.each { |file| require file }

module ScopesExtractor
  # The Extract class manages the process of extracting and comparing bug bounty program scopes
  # from multiple platforms, handling notifications when changes are detected.
  class Extract
    # List of supported bug bounty platforms
    PLATFORMS = %w[Immunefi YesWeHack Intigriti Hackerone Bugcrowd].freeze

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
      intigriti_sync
      hackerone_sync
      bugcrowd_sync

      Utilities::ScopeComparator.compare_and_notify(current_data, results, PLATFORMS) unless current_data.empty?

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
      Immunefi::Programs.sync(results['Immunefi'])
    end

    # Checks if Intigriti is configured with required credentials
    # @return [Boolean] True if YesWeHack is configured, false otherwise
    def intigriti_configured?
      config.dig(:intigriti, :token)
    end

    # Syncs data from Intigriti platform
    # @return [void]
    def intigriti_sync
      return unless intigriti_configured?

      config[:intigriti][:headers] = { Authorization: "Bearer #{config.dig(:intigriti, :token)}" }
      Intigriti::Programs.sync(results['Intigriti'], config[:intigriti])
    end

    # Checks if Hackerone is configured with required credentials
    # @return [Boolean] True if Hackerone is configured, false otherwise
    def hackerone_configured?
      config.dig(:hackerone, :username) && config.dig(:hackerone, :token)
    end

    # Syncs data from Hackerone platform
    # @return [void]
    def hackerone_sync
      return unless hackerone_configured?

      basic = Base64.urlsafe_encode64("#{config[:hackerone][:username]}:#{config[:hackerone][:token]}")
      config[:hackerone][:headers] = { Authorization: "Basic #{basic}" }

      Hackerone::Programs.sync(results['Hackerone'], config[:hackerone])
    end

    # Checks if Bugcrowd is configured with required credentials
    # @return [Boolean] True if Hackerone is configured, false otherwise
    def bugcrowd_configured?
      config.dig(:bugcrowd, :email) && config.dig(:bugcrowd, :password) && config.dig(:bugcrowd, :otp)
    end

    # Syncs data from Bugcrowd platform
    # @return [void]
    def bugcrowd_sync
      return unless bugcrowd_configured?

      bc_authenticated = Bugcrowd.authenticate(config[:bugcrowd])
      Discord.log_warn('Bugcrowd - Authentication Failed') unless bc_authenticated

      Bugcrowd::Programs.sync(results['Bugcrowd']) if bc_authenticated
    end
  end
end
