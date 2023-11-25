# frozen_string_literal: true

require 'typhoeus'

module ScopesExtractor
  # HttpClient
  module HttpClient
    @options = { ssl_verifypeer: false, ssl_verifyhost: 0 }

    def self.post(url, options = {})
      @options[:headers] = options[:headers] || { 'Content-Type' => 'application/json' }
      @options[:body] = options[:body]

      Typhoeus.post(url, @options)
    end
  end
end
