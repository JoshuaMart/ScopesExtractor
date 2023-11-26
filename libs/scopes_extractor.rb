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
      unless jwt
        Utilities.log_warn('YesWeHack - Authentication Failed')
        return
      end

      config[:yeswehack][:headers] = { 'Content-Type' => 'application/json', Authorization: "Bearer #{jwt}" }
      YesWeHack::Programs.sync(results, config[:yeswehack])

      File.open('extract.json', 'w') { |f| f.write(JSON.pretty_generate(results)) }
    end
  end
end
