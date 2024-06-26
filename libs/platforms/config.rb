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
        },
        bugcrowd: {
          email: ENV['BC_EMAIL'],
          password: ENV['BC_PWD']
        },
        hackerone: {
          username: ENV['H1_USERNAME'],
          token: ENV['H1_TOKEN']
        }
      }
    end
  end
end
