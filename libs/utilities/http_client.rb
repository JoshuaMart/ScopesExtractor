# frozen_string_literal: true

require 'faraday'
require 'faraday-cookie_jar'

module ScopesExtractor
  # HttpClient
  module HttpClient
    @client = Faraday.new do |builder|
      builder.use :cookie_jar
      builder.adapter Faraday.default_adapter
    end

    def self.get(url, options = {})
      headers = options[:headers]

      @client.get(url, nil, headers)
    end

    def self.post(url, options = {})
      body = options[:body]
      headers = options[:headers]

      @client.post(url, body, headers)
    end
  end
end