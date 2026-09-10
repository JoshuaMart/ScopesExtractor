# frozen_string_literal: true

module ScopesExtractor
  module Notifiers
    # Fans out every notification to all configured notifiers.
    # A failing notifier never prevents the others from being notified.
    class Multi
      NOTIFY_METHODS = %i[
        notify_new_program notify_removed_program notify_new_scope
        notify_removed_scope notify_ignored_asset notify_error
      ].freeze

      # Default set of notifiers, each one self-disables when not configured.
      def self.default
        new([Discord.new, Webhook.new])
      end

      def initialize(notifiers)
        @notifiers = notifiers
      end

      NOTIFY_METHODS.each do |method_name|
        define_method(method_name) do |*args, **kwargs|
          @notifiers.each do |notifier|
            notifier.public_send(method_name, *args, **kwargs)
          rescue StandardError => e
            ScopesExtractor.logger.error "#{notifier.class} ##{method_name} failed: #{e.message}"
          end
        end
      end
    end
  end
end
