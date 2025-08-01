# frozen_string_literal: true

require 'dotenv/load'
require 'yaml'

module ScopesExtractor
  # Config class manages application configuration loaded from environment variables
  # for various services and APIs used in the application
  class Config
    # Loads configuration from environment variables
    # @return [Hash] A hash containing application configuration
    def self.load
      {
        yeswehack: yeswehack_config,
        intigriti: intigriti_config,
        hackerone: hackerone_config,
        bugcrowd: bugcrowd_config,
        immunefi: immunefi_config,
        discord: discord_config,
        api: api_config,
        sync: sync_config,
        history: history_config,
        parser: parser_config
      }
    end

    # Private class methods for configuration segments
    class << self
      private

      def yeswehack_config
        {
          enabled: ENV.fetch('YWH_SYNC', false),
          email: ENV.fetch('YWH_EMAIL', nil),
          password: ENV.fetch('YWH_PWD', nil),
          otp: ENV.fetch('YWH_OTP', nil)
        }
      end

      def intigriti_config
        {
          enabled: ENV.fetch('INTIGRITI_SYNC', false),
          token: ENV.fetch('INTIGRITI_TOKEN', nil)
        }
      end

      def hackerone_config
        {
          enabled: ENV.fetch('H1_SYNC', false),
          username: ENV.fetch('H1_USERNAME', nil),
          token: ENV.fetch('H1_TOKEN', nil)
        }
      end

      def bugcrowd_config
        {
          enabled: ENV.fetch('BC_SYNC', false),
          email: ENV.fetch('BC_EMAIL', nil),
          password: ENV.fetch('BC_PWD', nil),
          otp: ENV.fetch('BC_OTP', nil)
        }
      end

      def immunefi_config
        {
          enabled: ENV.fetch('IMMUNEFI_SYNC', false)
        }
      end

      def discord_config
        {
          message_webhook: ENV.fetch('DISCORD_WEBHOOK', nil),
          logs_webhook: ENV.fetch('DISCORD_LOGS_WEBHOOK', nil),
          notify_categories: ENV.fetch('NOTIFY_CATEGORIES', 'all'),
          headers: { 'Content-Type' => 'application/json' }
        }
      end

      def api_config
        {
          enabled: ENV.fetch('API_MODE', false),
          key: ENV.fetch('API_KEY', nil)
        }
      end

      def sync_config
        {
          auto: ENV.fetch('AUTO_SYNC', false),
          delay: ENV.fetch('SYNC_DELAY', 10_800)
        }
      end

      def history_config
        {
          retention_days: ENV.fetch('HISTORY_RETENTION_DAYS', 30).to_i
        }
      end

      def parser_config
        {
          notify_uri_errors: ENV.fetch('NOTIFY_URI_ERRORS', 'true').downcase == 'true',
          notify_intigriti_403_errors: ENV.fetch('NOTIFY_INTIGRITI_403_ERRORS', 'true').downcase == 'true',
          exclusions: load_exclusions
        }
      end

      def load_exclusions
        config_path = File.join(File.dirname(__FILE__), '..', '..', 'config', 'exclusions.yml')
        if File.exist?(config_path)
          config = YAML.safe_load(File.read(config_path))
          config['exclusions'] || []
        else
          []
        end
      end
    end
  end
end
