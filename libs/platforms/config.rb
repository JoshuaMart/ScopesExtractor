# frozen_string_literal: true

require 'dotenv/load'

module ScopesExtractor
  # Config
  class Config
    def self.load
      {
        yeswehack: {
          email: ENV['YWH_EMAIL'],
          password: ENV['YWH_PWD'],
          otp: ENV['YWH_OTP']
        },
        intigriti: {
          token: ENV['INTIGRITI_TOKEN']
        }
      }
    end
  end
end
