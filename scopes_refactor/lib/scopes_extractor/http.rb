# frozen_string_literal: true

require 'typhoeus'

module ScopesExtractor
  module HTTP
    class << self
      attr_reader :hydra, :cookie_file

      def setup
        @hydra = Typhoeus::Hydra.new(max_concurrency: 10)
        @cookie_file = File.join(Dir.tmpdir, "scopes_extractor_cookies_#{Process.pid}.txt")
        ScopesExtractor.logger.info "HTTP client initialized with User-Agent: #{Config.user_agent}"
      end

      def get(url, headers: {}, timeout: nil)
        request(:get, url, headers: headers, timeout: timeout)
      end

      def post(url, body:, headers: {}, timeout: nil)
        request(:post, url, body: body, headers: headers, timeout: timeout)
      end

      private

      def request(method, url, body: nil, headers: {}, timeout: nil)
        options = build_options(body, headers, timeout)

        response = Typhoeus::Request.new(url, options.merge(method: method)).run

        log_request(method, url, response)
        response
      end

      def build_options(body, headers, timeout)
        options = {
          headers: default_headers.merge(headers),
          timeout: timeout || Config.timeout,
          followlocation: true,
          cookiefile: @cookie_file,
          cookiejar: @cookie_file
        }

        options[:body] = body if body
        options[:proxy] = Config.proxy if Config.proxy
        options
      end

      def default_headers
        {
          'User-Agent' => Config.user_agent
        }
      end

      def log_request(method, url, response)
        method_str = method.to_s.upcase
        status = response.code
        time = response.total_time.round(2)

        if response.success?
          ScopesExtractor.logger.debug "#{method_str} #{url} → #{status} (#{time}s)"
        else
          ScopesExtractor.logger.warn "#{method_str} #{url} → #{status} (#{time}s)"
        end
      end
    end
  end
end
