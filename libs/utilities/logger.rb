# frozen_string_literal: true

require 'logger'
require 'colorize'

module ScopesExtractor
  # Provides helper methods to be used in all the different classes
  module Utilities
    # Creates a singleton logger
    def self.logger
      @logger ||= Logger.new($stdout)
    end

    # Set the log level for the previous logger
    def self.log_level=(level)
      logger.level = level.downcase.to_sym
    end

    def self.log_fatal(message)
      logger.fatal(message.red)

      exit
    end

    def self.log_info(message)
      logger.info(message.green)
    end

    def self.log_control(message)
      logger.info(message.light_blue)
    end

    def self.log_warn(message)
      logger.warn(message.yellow)
    end
  end
end
