# frozen_string_literal: true

require 'typhoeus'

module ScopesExtractor
  # HttpClient
  module HttpClient
    @options = { ssl_verifypeer: false, ssl_verifyhost: 0 }

    def self.get(url, options = {})
      @options.merge!(options)

      Typhoeus.get(url, @options)
    end

    def self.post(url, options = {})
      @options.merge!(options)

      Typhoeus.post(url, @options)
    end
  end
end
