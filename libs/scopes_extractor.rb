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
      @results = { 'YesWeHack' => {}, 'Intigriti' => {}, 'Bugcrowd' => {} }
    end

    def run
      bc_authenticated = Bugcrowd.authenticate(config[:bugcrowd])
      Utilities.log_warn('Bugcrowd - Authentication Failed') unless bc_authenticated
      Bugcrowd::Programs.sync(results['Bugcrowd']) if bc_authenticated

      jwt = YesWeHack.authenticate(config[:yeswehack])
      Utilities.log_warn('YesWeHack - Authentication Failed') unless jwt

      config[:yeswehack][:headers] = { 'Content-Type' => 'application/json', Authorization: "Bearer #{jwt}" }
      YesWeHack::Programs.sync(results, config[:yeswehack]) if jwt

      if config.dig(:intigriti, :token)
        config[:intigriti][:headers] = { Authorization: "Bearer #{config[:intigriti][:token]}" }
        Intigriti::Programs.sync(results, config[:intigriti]) 
      end

      File.open('extract.json', 'w') { |f| f.write(JSON.pretty_generate(results)) }
    end
  end
end
