# frozen_string_literal: true

module ScopesExtractor
  module Config
    class << self
      def load
        @load ||= YAML.load_file(config_path, symbolize_names: true)
      end

      def reload
        @load = nil
        load
      end

      def app
        load[:app] || {}
      end

      def log_level
        app[:log_level] || 'INFO'
      end

      def database_path
        app[:database_path] || 'db/scopes.db'
      end

      def http
        load[:http] || {}
      end

      def user_agent
        http[:user_agent] || 'ScopesExtractor/2.0'
      end

      def proxy
        http[:proxy]
      end

      def timeout
        http[:timeout] || 30
      end

      def api
        load[:api] || {}
      end

      def api_port
        api[:port] || 4567
      end

      def api_bind
        api[:bind] || '0.0.0.0'
      end

      def platforms
        load[:platforms] || {}
      end

      def platform_enabled?(platform_name)
        platforms.dig(platform_name.to_sym, :enabled) == true
      end

      def skip_vdp?(platform_name)
        platforms.dig(platform_name.to_sym, :skip_vdp) == true
      end

      def sync
        load[:sync] || {}
      end

      def history_retention_days
        load[:history_retention_days] || 30
      end

      def discord
        load[:discord] || {}
      end

      def discord_enabled?
        discord[:enabled] == true
      end

      def discord_webhooks
        discord[:webhooks] || {}
      end

      def discord_main_webhook
        discord_webhooks[:main] || {}
      end

      def discord_errors_webhook
        discord_webhooks[:errors] || {}
      end

      def discord_events
        discord_main_webhook[:events] || []
      end

      def discord_new_scope_types
        discord_main_webhook[:new_scope_types] || []
      end

      def platform_exclusions
        load[:platform_exclusions] || {}
      end

      def excluded?(platform_name, program_slug)
        exclusions = platform_exclusions[platform_name.to_sym] || []
        exclusions.include?(program_slug)
      end

      private

      def config_path
        File.join(ScopesExtractor.root, 'config', 'settings.yml')
      end
    end
  end
end
