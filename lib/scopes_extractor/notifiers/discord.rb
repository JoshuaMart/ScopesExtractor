# frozen_string_literal: true

require 'json'
require 'concurrent-ruby'

module ScopesExtractor
  module Notifiers
    class Discord
      COLORS = {
        info: 5_025_616,
        success: 65_280,
        warn: 16_771_899,
        error: 16_711_680
      }.freeze

      # Thread-safe hash for rate limit tracking (mutable)
      RATE_LIMIT_CACHE = Concurrent::Hash.new

      def initialize
        @main_webhook = Config.discord_main_webhook[:url]
        @error_webhook = Config.discord_errors_webhook[:url]
        @events = Config.discord_events
        @new_scope_types = Config.discord_new_scope_types
      end

      def notify_new_program(platform, program_name, slug)
        return unless enabled? && event_enabled?('new_program')

        title = "🆕 New Program: #{program_name}"
        description = "**Platform:** #{platform}\n**Slug:** `#{slug}`"
        send_notification(@main_webhook, title, description, :success)
      end

      def notify_removed_program(platform, program_name, slug)
        return unless enabled? && event_enabled?('removed_program')

        title = "❌ Removed Program: #{program_name}"
        description = "**Platform:** #{platform}\n**Slug:** `#{slug}`"
        send_notification(@main_webhook, title, description, :error)
      end

      def notify_new_scope(platform, program_name, value, type)
        return unless enabled? && event_enabled?('new_scope')
        return unless scope_type_enabled?(type)

        title = "🎯 New Scope: #{program_name}"
        description = "**Platform:** #{platform}\n**Type:** `#{type}`\n**Value:** `#{value}`"
        send_notification(@main_webhook, title, description, :success)
      end

      def notify_removed_scope(platform, program_name, value)
        return unless enabled? && event_enabled?('removed_scope')

        title = "🗑️ Removed Scope: #{program_name}"
        description = "**Platform:** #{platform}\n**Value:** `#{value}`"
        send_notification(@main_webhook, title, description, :warn)
      end

      def notify_ignored_asset(platform, program_name, value, reason)
        return unless enabled? && event_enabled?('ignored_asset')

        title = "🚫 Ignored Asset: #{program_name}"
        description = "**Platform:** #{platform}\n**Value:** `#{value}`\n**Reason:** #{reason}"
        send_notification(@main_webhook, title, description, :warn)
      end

      def notify_error(title, message)
        return unless enabled? && @error_webhook

        send_notification(@error_webhook, "❗ #{title}", message, :error)
      end

      private

      def enabled?
        Config.discord_enabled?
      end

      def event_enabled?(event_name)
        @events.empty? || @events.include?(event_name)
      end

      def scope_type_enabled?(type)
        @new_scope_types.empty? || @new_scope_types.include?(type)
      end

      def send_notification(webhook_url, title, description, level, retry_count: 0)
        return if webhook_url.nil? || webhook_url.empty?

        wait_for_rate_limit(webhook_url)

        payload = build_payload(title, description, level)
        response = HTTP.post(webhook_url, body: payload.to_json, headers: { 'Content-Type' => 'application/json' })

        handle_response(webhook_url, response, title, description, level, retry_count)
      rescue StandardError => e
        ScopesExtractor.logger.error "Discord notification error: #{e.message}"
      end

      def build_payload(title, description, level)
        {
          embeds: [{
            title: title,
            description: description,
            color: COLORS[level] || COLORS[:info],
            timestamp: Time.now.utc.iso8601
          }]
        }
      end

      def handle_response(webhook_url, response, title, description, level, retry_count)
        case response.code
        when 200..299
          update_rate_limit(webhook_url, response)
          sleep(0.5) # Safe cooldown
        when 429
          handle_rate_limit_error(webhook_url, response, title, description, level, retry_count)
        else
          ScopesExtractor.logger.error "Discord webhook failed: #{response.code} - #{response.body}"
        end
      end

      def update_rate_limit(webhook_url, response)
        remaining = response.headers['X-RateLimit-Remaining']&.to_i
        reset_after = response.headers['X-RateLimit-Reset-After']&.to_f

        return unless remaining && reset_after

        RATE_LIMIT_CACHE[webhook_url] = {
          remaining: remaining,
          reset_at: Time.now + reset_after
        }

        return unless remaining.zero? && reset_after.positive?

        ScopesExtractor.logger.debug "Discord rate limit reached, waiting #{reset_after}s"
        sleep(reset_after)
      end

      def handle_rate_limit_error(webhook_url, response, title, description, level, retry_count)
        max_retries = 3

        if retry_count >= max_retries
          ScopesExtractor.logger.error "Discord rate limit exceeded max retries (#{max_retries}), dropping notification"
          return
        end

        body = JSON.parse(response.body)
        retry_after = (body['retry_after'] || 5).to_f

        attempt_msg = "attempt #{retry_count + 1}/#{max_retries}"
        ScopesExtractor.logger.warn "Discord rate limited (429), waiting #{retry_after}s and retrying (#{attempt_msg})"

        RATE_LIMIT_CACHE[webhook_url] = {
          remaining: 0,
          reset_at: Time.now + retry_after
        }

        sleep(retry_after)

        # Retry the notification
        send_notification(webhook_url, title, description, level, retry_count: retry_count + 1)
      rescue JSON::ParserError
        sleep(5)
        if retry_count < max_retries
          send_notification(webhook_url, title, description, level,
                            retry_count: retry_count + 1)
        end
      end

      def wait_for_rate_limit(webhook_url)
        cache = RATE_LIMIT_CACHE[webhook_url]
        return unless cache

        return if cache[:remaining]&.positive?
        return unless cache[:reset_at] && cache[:reset_at] > Time.now

        wait_time = (cache[:reset_at] - Time.now).ceil
        ScopesExtractor.logger.debug "Waiting #{wait_time}s for Discord rate limit reset"
        sleep(wait_time)

        RATE_LIMIT_CACHE.delete(webhook_url)
      end
    end
  end
end
