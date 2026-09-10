# frozen_string_literal: true

require 'json'
require 'time'

module ScopesExtractor
  module Notifiers
    # Sends notifications as JSON payloads to a generic HTTP endpoint.
    #
    # Every payload shares the same envelope:
    #   { "event": "<event_name>", "timestamp": "<ISO8601 UTC>", "data": { ... } }
    #
    # Custom headers (e.g. an Authorization header) can be declared in the
    # configuration and may reference environment variables as "${VAR}".
    class Webhook
      DEFAULT_HEADERS = { 'Content-Type' => 'application/json' }.freeze

      def initialize
        @url = Config.webhook_url
        @headers = DEFAULT_HEADERS.merge(Config.webhook_headers)
        @events = Config.webhook_events
        @new_scope_types = Config.webhook_new_scope_types
      end

      def notify_new_program(platform, program_name, slug, scope_stats: {})
        publish('new_program', platform: platform, program: program_name, slug: slug,
                               scopes_count: scope_stats.values.sum, scopes: stringify_stats(scope_stats))
      end

      def notify_removed_program(platform, program_name, slug)
        publish('removed_program', platform: platform, program: program_name, slug: slug)
      end

      def notify_new_scope(platform, program_name, value, type)
        return unless scope_type_enabled?(type)

        publish('new_scope', platform: platform, program: program_name, value: value, type: type)
      end

      def notify_removed_scope(platform, program_name, value)
        publish('removed_scope', platform: platform, program: program_name, value: value)
      end

      def notify_ignored_asset(platform, program_name, value, reason)
        publish('ignored_asset', platform: platform, program: program_name, value: value, reason: reason)
      end

      def notify_error(title, message)
        publish('error', title: title, message: message)
      end

      private

      def enabled?
        Config.webhook_enabled? && !@url.to_s.empty?
      end

      def event_enabled?(event_name)
        @events.empty? || @events.include?(event_name)
      end

      def scope_type_enabled?(type)
        @new_scope_types.empty? || @new_scope_types.include?(type.to_s)
      end

      def stringify_stats(scope_stats)
        scope_stats.transform_keys(&:to_s)
      end

      def publish(event, **data)
        return unless enabled? && event_enabled?(event)

        payload = { event: event, timestamp: Time.now.utc.iso8601, data: data }
        response = HTTP.post(@url, body: payload.to_json, headers: @headers)

        return if (200..299).cover?(response.code)

        ScopesExtractor.logger.error "Webhook notification failed: #{response.code} - #{response.body}"
      rescue StandardError => e
        ScopesExtractor.logger.error "Webhook notification error: #{e.message}"
      end
    end
  end
end
