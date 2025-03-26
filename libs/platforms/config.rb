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
        yeswehack: {
          email: ENV.fetch('YWH_EMAIL', nil),
          password: ENV.fetch('YWH_PWD', nil),
          otp: ENV.fetch('YWH_OTP', nil)
        },
        intigriti: {
          token: ENV.fetch('INTIGRITI_TOKEN', nil)
        },
        discord: {
          message_webhook: ENV.fetch('DISCORD_WEBHOOK', nil),
          logs_webhook: ENV.fetch('DISCORD_LOGS_WEBHOOK', nil),
          headers: { 'Content-Type' => 'application/json' }
        },
        api: {
          enabled: ENV.fetch('API_MODE', false),
          key: ENV.fetch('API_KEY', nil)
        },
        sync: {
          auto: ENV.fetch('AUTO_SYNC', false),
          delay: ENV.fetch('SYNC_DELAY', 10_800)
        }
      }
    end
  end
end
