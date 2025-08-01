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

    # Gets recent changes from the history
    # @param hours [Integer] Number of hours to look back (default: 48)
    # @param filters [Hash] Optional filters for the changes (platform, program, change_type)
    # @return [Array] Array of recent changes matching the criteria
    def get_recent_changes(hours = 48, filters = {})
      DB.get_recent_changes(hours, filters)
    end

    # Gets all wildcard domains from current programs
    # @param filters [Hash] Optional filters (platform, program)
    # @return [Array] Array of wildcard domains with metadata
    def get_wildcards(filters = {})
      current_data = DB.load
      extract_wildcards(current_data, filters)
    end

    private

    # Processes an API request by verifying the API key in the header and returning the appropriate data in JSON.
    #
    # @param req [WEBrick::HTTPRequest] The incoming HTTP request object.
    # @param res [WEBrick::HTTPResponse] The HTTP response object that will be returned.
    # @return [void]
    def api_response(req, res)
      api_key = req.header['x-api-key']&.first
      res.content_type = 'application/json'

      return unauthorized_response(res) unless valid_api_key?(api_key)

      path = req.path
      query = req.query || {}

      if path.start_with?('/changes')
        handle_changes_request(res, query)
      elsif path.start_with?('/wildcards')
        handle_wildcards_request(res, query)
      else
        handle_default_request(res)
      end
    end

    # Validates if the provided API key matches the configured key.
    #
    # @param api_key [String, nil] The API key from the request header.
    # @return [Boolean] True if the API key is valid, false otherwise.
    def valid_api_key?(api_key)
      api_key == config.dig(:api, :key)
    end

    # Sends an unauthorized response with 401 status code.
    #
    # @param res [WEBrick::HTTPResponse] The HTTP response object to be modified.
    # @return [void]
    def unauthorized_response(res)
      res.status = 401
      res.body = { error: 'Unauthorized' }.to_json
    end

    # Handles requests to the /changes endpoint, applying appropriate filters.
    #
    # @param res [WEBrick::HTTPResponse] The HTTP response object to be modified.
    # @param query [Hash] The query parameters from the request.
    # @return [void]
    def handle_changes_request(res, query)
      hours = (query['hours'] || 48).to_i
      filters = extract_filters(query)
      res.body = get_recent_changes(hours, filters).to_json
    end

    # Handles requests to the /wildcards endpoint, applying appropriate filters.
    #
    # @param res [WEBrick::HTTPResponse] The HTTP response object to be modified.
    # @param query [Hash] The query parameters from the request.
    # @return [void]
    def handle_wildcards_request(res, query)
      filters = extract_wildcard_filters(query)
      res.body = get_wildcards(filters).to_json
    end

    # Extracts relevant filters from the query parameters.
    #
    # @param query [Hash] The query parameters from the request.
    # @return [Hash] A hash containing only the non-nil filter values.
    def extract_filters(query)
      {
        platform: query['platform'],
        change_type: query['type'],
        program: query['program'],
        category: query['category']
      }.compact
    end

    # Extracts relevant filters for wildcard requests from the query parameters.
    #
    # @param query [Hash] The query parameters from the request.
    # @return [Hash] A hash containing only the non-nil filter values.
    def extract_wildcard_filters(query)
      {
        platform: query['platform'],
        program: query['program']
      }.compact
    end

    # Extracts wildcard domains from program data
    #
    # @param data [Hash] The program data to search through
    # @param filters [Hash] Optional filters to apply (platform, program)
    # @return [Array] Array of wildcard entries with metadata
    def extract_wildcards(data, filters = {})
      wildcards = []

      data.each do |platform, programs|
        # Apply platform filter if specified
        next if filters[:platform] && platform != filters[:platform]

        programs.each do |program_name, program_data|
          # Apply program filter if specified
          next if filters[:program] && program_name != filters[:program]

          # Extract wildcards from in-scope web targets
          scopes = program_data['scopes'] || {}
          in_scopes = scopes['in'] || {}
          web_scopes = in_scopes['web'] || []

          web_scopes.each do |scope|
            next unless scope.start_with?('*.')

            wildcards << {
              'domain' => scope,
              'platform' => platform,
              'program' => program_name,
              'slug' => program_data['slug'],
              'private' => program_data['private'] || false
            }
          end
        end
      end

      # Sort by domain for consistent output
      wildcards.sort_by { |w| w['domain'] }
    end

    # Handles the default API request by returning the current state.
    #
    # @param res [WEBrick::HTTPResponse] The HTTP response object to be modified.
    # @return [void]
    def handle_default_request(res)
      res.body = DB.load.to_json
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
          rescue StandardError => e
            Discord.log_error("Error during sync_platform : #{e}")
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

    # Helper method to handle authentication retries
    # @param platform [String] Platform name for logging
    # @param max_retries [Integer] Maximum number of retry attempts
    # @param retry_delay [Integer] Delay in seconds between retry attempts
    # @yield [Block] Block executing the authentication and returning a hash with :error or :success
    # @return [Hash, nil] Authentication result or nil if all attempts fail
    def with_authentication_retry(platform, max_retries: 2, retry_delay: 30)
      retries = 0

      loop do
        result = yield

        return result unless result[:error] || (result.key?(:success) && !result[:success])

        error_msg = result[:error] || 'Unknown error'
        Discord.log_warn("#{platform} - Authentication Failed with error: #{error_msg}")

        retries += 1
        if retries >= max_retries
          Discord.log_warn("#{platform} - Max retries (#{max_retries}) reached. Giving up.")
          return nil
        end

        Discord.log_info("#{platform} - Retrying in #{retry_delay} seconds... (Attempt #{retries}/#{max_retries})")
        sleep(retry_delay)
      end
    end

    # Checks if YesWeHack is configured with required credentials
    # @return [Boolean] True if YesWeHack is configured, false otherwise
    def yeswehack_configured?
      return false if config.dig(:yeswehack, :enabled) == 'false'

      !!(config.dig(:yeswehack, :email) && config.dig(:yeswehack, :password) && config.dig(:yeswehack, :otp))
    end

    # Syncs data from YesWeHack platform
    # @return [void]
    def yeswehack_sync
      return unless yeswehack_configured?

      auth_result = with_authentication_retry('YesWeHack') do
        YesWeHack.authenticate(config[:yeswehack])
      end
      return unless auth_result

      config[:yeswehack][:headers] = {
        'Content-Type' => 'application/json',
        Authorization: "Bearer #{auth_result[:jwt]}"
      }
      YesWeHack::Programs.sync(results['YesWeHack'], config[:yeswehack])
    end

    # Checks if Immunefi is configured
    # @return [Boolean] True if Immunefi is configured, false otherwise
    def immunefi_configured?
      config.dig(:immunefi, :enabled) != 'false'
    end

    # Syncs data from Immunefi platform
    # @return [void]
    def immunefi_sync
      return unless immunefi_configured?

      Immunefi::Programs.sync(results['Immunefi'])
    end

    # Checks if Intigriti is configured with required credentials
    # @return [Boolean] True if YesWeHack is configured, false otherwise
    def intigriti_configured?
      return false if config.dig(:intigriti, :enabled) == 'false'

      config.dig(:intigriti, :token)
    end

    # Syncs data from Intigriti platform
    # @return [void]
    def intigriti_sync
      return unless intigriti_configured?

      config[:intigriti][:headers] = { Authorization: "Bearer #{config.dig(:intigriti, :token)}" }
      Intigriti::Programs.sync(results['Intigriti'], config)
    end

    # Checks if Hackerone is configured with required credentials
    # @return [Boolean] True if Hackerone is configured, false otherwise
    def hackerone_configured?
      return false if config.dig(:hackerone, :enabled) == 'false'

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
      return false if config.dig(:bugcrowd, :enabled) == 'false'

      config.dig(:bugcrowd, :email) && config.dig(:bugcrowd, :password) && config.dig(:bugcrowd, :otp)
    end

    # Syncs data from Bugcrowd platform
    # @return [void]
    def bugcrowd_sync
      return unless bugcrowd_configured?

      auth_result = with_authentication_retry('Bugcrowd') do
        Bugcrowd.authenticate(config[:bugcrowd])
      end
      return unless auth_result

      Bugcrowd::Programs.sync(results['Bugcrowd'])
    end
  end
end
