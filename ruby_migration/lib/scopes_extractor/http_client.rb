# frozen_string_literal: true

require 'faraday'
require 'faraday/retry'
require 'faraday/cookie_jar'
require 'faraday/follow_redirects'
require 'http/cookie'

module ScopesExtractor
  class HttpClient
    def self.cookie_jar
      @cookie_jar ||= HTTP::CookieJar.new
    end

    def self.new(proxy: nil, user_agent: nil)
      user_agent ||= 'ScopesExtractor/1.0 (Ruby; +github.com/JoshuaMart/ScopesExtractor)'
      proxy ||= ENV.fetch('HTTP_PROXY', nil)

      Faraday.new do |f|
        f.request :url_encoded
        f.request :json

        f.request :retry, {
          max: 3,
          interval: 5,
          backoff_factor: 2,
          exceptions: [Faraday::Error, StandardError]
        }

        f.headers['User-Agent'] = user_agent
        f.proxy = proxy if proxy

        # Bugcrowd needs cookie persistence
        f.use :cookie_jar, jar: ScopesExtractor::HttpClient.cookie_jar

        f.adapter Faraday.default_adapter
      end
    end
  end
end
