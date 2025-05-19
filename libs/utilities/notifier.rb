# frozen_string_literal: true

require_relative '../platforms/config'

module ScopesExtractor
  # Discord module handles sending notification messages to Discord webhooks
  # for various events and system logs
  module Discord
    # Loads Discord configuration from the global config
    # @return [Hash] Discord configuration
    def self.config
      @config ||= ScopesExtractor::Config.load[:discord]
    end

    # Sends a warning log message to Discord
    # @param message [String] Warning message to send
    # @return [void]
    def self.log_warn(message)
      notify('⚠️ WARNING', message, 16_771_899, :logs_webhook)
    end

    # Sends a warning log message to Discord
    # @param message [String] Warning message to send
    # @return [void]
    def self.log_error(message)
      notify('⚠️ ERROR', message, 14_549_051, :logs_webhook)
    end

    # Sends an informational log message to Discord
    # @param message [String] Info message to send
    # @return [void]
    def self.log_info(message)
      notify('ℹ️ INFO', message, 5_025_616, :logs_webhook)
    end

    # Notifies about a new program addition
    # @param platform [String] Platform name
    # @param title [String] Program title
    # @param _slug [String] Program slug (unused)
    # @param _private [Boolean] Whether the program is private (unused)
    # @return [void]
    def self.new_program(platform, title, _slug, _private)
      notify('🆕 Program add', "The program '#{title}' has been added to #{platform}", 5_025_616)
    end

    # Notifies about a program removal
    # @param platform [String] Platform name
    # @param title [String] Program title
    # @return [void]
    def self.removed_program(platform, title)
      notify('🗑 Program removed', "The program '#{title}' has been removed from #{platform}", 16_711_680)
    end

    # Notifies about a new scope addition
    # @param platform [String] Platform name
    # @param program [String] Program title
    # @param value [String] Scope value
    # @param category [String] Scope category
    # @param in_scope [Boolean] Whether the scope is in-scope (true) or out-of-scope (false)
    # @return [void]
    def self.new_scope(platform, program, value, category, in_scope)
      # Do not send notifications for disabled categories
      return unless config[:notify_categories] == 'all' || config[:notify_categories].split(',').include?(category)

      notify('🆕 New scope', "In #{platform} - Program '#{program}': #{scope_label(value, category, in_scope)} added",
             65_280)
    end

    # Notifies about a scope removal
    # @param platform [String] Platform name
    # @param program [String] Program title
    # @param value [String] Scope value
    # @param category [String] Scope category
    # @param in_scope [Boolean] Whether the scope is in-scope (true) or out-of-scope (false)
    # @return [void]
    def self.removed_scope(platform, program, value, category, in_scope)
      # Do not send notifications for disabled categories
      return unless config[:notify_categories] == 'all' || config[:notify_categories].split(',').include?(category)

      notify('🗑 Scope removed',
             "In #{platform} - Program '#{program}': #{scope_label(value, category, in_scope)} removed", 16_711_680)
    end

    # Creates a formatted scope label
    # @param value [String] Scope value
    # @param category [String] Scope category
    # @param in_scope [Boolean] Whether the scope is in-scope
    # @return [String] Formatted scope label
    def self.scope_label(value, category, in_scope)
      scope_type = in_scope ? 'In Scope' : 'Out of Scope'
      "[#{scope_type}] (#{category}) #{value}"
    end

    # Sends a notification to Discord through a webhook
    # @param title [String] Notification title
    # @param description [String] Notification description
    # @param color [Integer] Embed color
    # @param webhook [Symbol] Webhook to use (:message_webhook or :logs_webhook)
    # @return [void]
    def self.notify(title, description, color, webhook = :message_webhook)
      return unless config[webhook] && !config[webhook].empty?

      embed = { title: title, description: description, color: color }
      body = { embeds: [embed] }.to_json

      resp = HttpClient.post(config[webhook], { headers: config[:headers], body: body })

      ratelimit_remaining = resp.headers['x-ratelimit-remaining']&.to_i
      ratelimit_reset_after = resp.headers['x-ratelimit-reset-after']&.to_i

      sleep(ratelimit_reset_after) if ratelimit_remaining&.zero?
    end
  end
end
