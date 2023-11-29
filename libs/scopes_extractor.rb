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
      @results = { 'YesWeHack' => {}, 'Intigriti' => {} }
    end

    def run
      jwt = YesWeHack.authenticate(config[:yeswehack])
      Utilities.log_warn('YesWeHack - Authentication Failed') unless jwt

      config[:yeswehack][:headers] = { 'Content-Type' => 'application/json', Authorization: "Bearer #{jwt}" }
      YesWeHack::Programs.sync(results, config[:yeswehack]) if jwt

      cookie = Intigriti.authenticate(config[:intigriti])
      Utilities.log_warn('Intigriti - Authentication Failed') unless cookie

      config[:intigriti][:headers] = { 'Cookie' => "__Host-Intigriti.Web.Researcher=#{cookie}" }
      Intigriti::Programs.sync(results, config[:intigriti]) if cookie

      File.open('extract.json', 'w') { |f| f.write(JSON.pretty_generate(results)) }
    end
  end
end
