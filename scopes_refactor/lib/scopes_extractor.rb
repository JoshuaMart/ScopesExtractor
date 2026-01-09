# frozen_string_literal: true

require 'dotenv/load'
require 'logger'
require 'colorize'
require 'sequel'
require 'yaml'

module ScopesExtractor
  class << self
    attr_accessor :db, :logger, :notifier

    def root
      @root ||= File.expand_path('..', __dir__)
    end

    def setup_logger
      @logger = Logger.new($stdout)
      @logger.level = log_level_from_env
      @logger.formatter = proc do |severity, datetime, _progname, msg|
        timestamp = datetime.strftime('%Y-%m-%d %H:%M:%S')
        colored_severity = colorize_severity(severity)
        "[#{timestamp}] #{colored_severity} #{msg}\n"
      end
      @logger
    end

    private

    def log_level_from_env
      require_relative 'scopes_extractor/config'
      level = Config.log_level.upcase

      case level
      when 'DEBUG' then Logger::DEBUG
      when 'WARN' then Logger::WARN
      when 'ERROR' then Logger::ERROR
      else
        Logger::INFO
      end
    end

    def colorize_severity(severity)
      case severity
      when 'DEBUG' then severity.light_black
      when 'INFO' then severity.light_blue
      when 'WARN' then severity.yellow
      when 'ERROR' then severity.light_red
      when 'FATAL' then severity.red.bold
      else severity
      end
    end
  end
end

# Initialize logger
ScopesExtractor.setup_logger

# Require all core files
require_relative 'scopes_extractor/config'
require_relative 'scopes_extractor/database'
require_relative 'scopes_extractor/normalizer'
require_relative 'scopes_extractor/validator'
require_relative 'scopes_extractor/http'

# Require notifiers
require_relative 'scopes_extractor/notifiers/discord'

# Require models
require_relative 'scopes_extractor/models/scope'
require_relative 'scopes_extractor/models/program'

# Require diff engine
require_relative 'scopes_extractor/diff_engine'

# Require sync manager
require_relative 'scopes_extractor/sync_manager'

# Require platforms
require_relative 'scopes_extractor/platforms/base_platform'

# Initialize HTTP client
ScopesExtractor::HTTP.setup
