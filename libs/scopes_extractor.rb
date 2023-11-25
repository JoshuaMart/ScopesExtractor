# frozen_string_literal: true

require 'json'
require 'rotp'

Dir[File.join(__dir__, 'platforms', '**', '*.rb')].sort.each { |file| require file }
Dir[File.join(__dir__, 'utilities', '*.rb')].sort.each { |file| require file }

module ScopesExtractor
  # Extract
  class Extract
    attr_accessor :config, :results

    def initialize
      @config = Config.load
      @results = {}
    end

    def run
      results['YesWeHack'] = {}

      jwt = YesWeHack.authenticate(config[:yeswehack])
      return unless jwt

      config[:yeswehack][:headers] = { 'Content-Type' => 'application/json', Authorization: "Bearer #{jwt}" }
      YesWeHack::Programs.sync(results, config[:yeswehack])
    end
  end
end
