# frozen_string_literal: true

require 'zeitwerk'
require 'dotenv/load'
require 'logger'
require 'sequel'
require 'dry-struct'
require 'dry-types'

loader = Zeitwerk::Loader.for_gem
loader.setup

module ScopesExtractor
  class Error < StandardError; end

  def self.logger
    @logger ||= begin
      logger = Logger.new($stdout)
      logger.level = ENV.fetch('LOG_LEVEL', 'INFO')
      logger.formatter = proc do |severity, datetime, _progname, msg|
        color = case severity
                when 'INFO' then "\e[34m"    # Blue
                when 'WARN' then "\e[33m"    # Yellow
                when 'ERROR' then "\e[31m"   # Red
                when 'DEBUG' then "\e[36m"   # Cyan
                else "\e[0m"
                end
        "#{color}[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity.ljust(5)} : #{msg}\e[0m\n"
      end
      logger
    end
  end

  def self.notifier
    @notifier ||= begin
      webhook = ENV.fetch('DISCORD_WEBHOOK_URL', nil)
      logs_webhook = ENV.fetch('DISCORD_LOGS_WEBHOOK_URL', nil)
      Notifiers::Discord.new(webhook, logs_webhook)
    end
  end

  def self.db
    @db ||= begin
      db_path = ENV.fetch('DATABASE_URL', 'sqlite://db/scopes_extractor.sqlite3')
      Sequel.connect(db_path)
    end
  end

  # Graceful shutdown
  at_exit do
    @notifier&.stop
  end
end
