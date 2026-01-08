# frozen_string_literal: true

require 'json'

module ScopesExtractor
  module Notifiers
    class Discord
      # Notification levels and their colors (same as Go/original Ruby)
      COLORS = {
        info: 5_025_616, # Blue
        success: 65_280, # Green
        warn: 16_771_899,   # Orange
        error: 16_711_680   # Red
      }.freeze

      def initialize(webhook_url, logs_webhook_url = nil)
        @webhook_url = webhook_url
        @logs_webhook_url = logs_webhook_url || webhook_url
        @queue = Queue.new
        @client = HttpClient.new
        @running = true

        start_worker
      end

      def notify(title, description, level: :info)
        queue_message(@webhook_url, title, description, level)
      end

      def notify_new_program(platform, program_name, program_id)
        title = "🆕 New Program: #{program_name}"
        description = "**Platform:** #{platform}\n**ID:** `#{program_id}`"
        notify(title, description, level: :success)
      end

      def notify_removed_program(platform, program_name, program_id)
        title = "❌ Removed Program: #{program_name}"
        description = "**Platform:** #{platform}\n**ID:** `#{program_id}`"
        notify(title, description, level: :error)
      end

      def notify_new_scope(platform, program_name, scope, type)
        title = "🎯 New Scope: #{program_name}"
        description = "**Platform:** #{platform}\n**Type:** `#{type}`\n**Scope:** `#{scope}`"
        notify(title, description, level: :success)
      end

      def notify_removed_scope(platform, program_name, scope)
        title = "🗑️ Removed Scope: #{program_name}"
        description = "**Platform:** #{platform}\n**Scope:** `#{scope}`"
        notify(title, description, level: :warn)
      end

      def notify_ignored_asset(platform, program_name, scope, reason)
        title = "🚫 Auto-Ignored Asset: #{program_name}"
        description = "**Platform:** #{platform}\n**Scope:** `#{scope}`\n**Reason:** #{reason}"
        notify(title, description, level: :warn)
      end

      def log(title, message, level: :info)
        queue_message(@logs_webhook_url, title, message, level)
      end

      def stop
        @running = false
        @worker&.join(5) # Wait up to 5s for the queue to flush
      end

      private

      def queue_message(url, title, description, level)
        return if url.nil? || url.empty?

        @queue << {
          url: url,
          payload: {
            embeds: [{
              title: title,
              description: description,
              color: COLORS[level] || COLORS[:info],
              timestamp: Time.now.iso8601
            }]
          }
        }
      end

      def start_worker
        @worker = Thread.new do
          while @running || !@queue.empty?
            msg = begin
              @queue.pop(true)
            rescue StandardError
              nil
            end
            next if msg.nil?

            send_to_discord(msg)
          end
        end
      end

      def send_to_discord(msg)
        response = @client.post(msg[:url]) do |req|
          req.headers['Content-Type'] = 'application/json'
          req.body = msg[:payload].to_json
        end

        case response.status
        when 200..299
          # Success, handle rate limit headers if needed
          handle_rate_limit(response)
        when 429
          # Rate limit hit, retry after delay
          retry_after = (JSON.parse(response.body)['retry_after'] || 5).to_f
          ScopesExtractor.logger.warn "Discord rate limit hit, waiting #{retry_after}s"
          sleep(retry_after)
          @queue << msg # Re-queue
        else
          ScopesExtractor.logger.error "Failed to send Discord notification: #{response.status} - #{response.body}"
        end
      rescue StandardError => e
        ScopesExtractor.logger.error "Error in Discord worker: #{e.message}"
        sleep(5) # Cooldown on network error
      end

      def handle_rate_limit(response)
        remaining = response.headers['X-RateLimit-Remaining'].to_i
        reset_after = response.headers['X-RateLimit-Reset-After'].to_f

        if remaining.zero? && reset_after.positive?
          ScopesExtractor.logger.debug "Discord quota exhausted, cooling down for #{reset_after}s"
          sleep(reset_after)
        else
          # Small mandatory pause to be safe
          sleep(0.5)
        end
      end
    end
  end
end
