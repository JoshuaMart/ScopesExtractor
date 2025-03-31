# frozen_string_literal: true

require 'dotenv/load'

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
        discord: discord_config,
        api: api_config,
        sync: sync_config
      }
    end

    # Private class methods for configuration segments
    class << self
      private

      def yeswehack_config
        {
          email: ENV.fetch('YWH_EMAIL', nil),
          password: ENV.fetch('YWH_PWD', nil),
          otp: ENV.fetch('YWH_OTP', nil)
        }
      end

      def intigriti_config
        {
          token: ENV.fetch('INTIGRITI_TOKEN', nil)
        }
      end

      def hackerone_config
        {
          username: ENV.fetch('H1_USERNAME', nil),
          token: ENV.fetch('H1_TOKEN', nil)
        }
      end

      def discord_config
        {
          message_webhook: ENV.fetch('DISCORD_WEBHOOK', nil),
          logs_webhook: ENV.fetch('DISCORD_LOGS_WEBHOOK', nil),
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
    end
  end
end
