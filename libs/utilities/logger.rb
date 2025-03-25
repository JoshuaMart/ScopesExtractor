# frozen_string_literal: true

require 'logger'
require 'colorize'

module ScopesExtractor
  # Provides helper methods to be used in all the different classes
  module Utilities
    # Creates a singleton logger
    def self.logger
      return @logger if @logger

      @logger = Logger.new($stdout)
      @logger.formatter = proc do |severity, datetime, _, msg|
        date_format = datetime.strftime('%Y-%m-%d %H:%M:%S')
        "[#{date_format}] #{severity}  #{msg}\n"
      end

      @logger
    end

    def self.log_warn(message)
      logger.warn(message.yellow)
    end

    def self.log_info(message)
      logger.info(message.blue)
    end
  end
end
