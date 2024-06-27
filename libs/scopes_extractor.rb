# frozen_string_literal: true

require 'json'
require 'rotp'
require 'base64'

Dir[File.join(__dir__, 'platforms', '**', '*.rb')].sort.each { |file| require file }
Dir[File.join(__dir__, 'utilities', '*.rb')].sort.each { |file| require file }

module ScopesExtractor
  # Extract
  class Extract
    attr_accessor :config, :results

    def initialize
      @config = Config.load
      @results = { 'YesWeHack' => {}, 'Intigriti' => {}, 'Bugcrowd' => {}, 'Hackerone' => {} }
    end

    def run
      # -- HACKERONE
      if config[:hackerone][:username] && config[:hackerone][:token]
        basic = Base64.urlsafe_encode64(config[:hackerone][:username] + ':' + config[:hackerone][:token])
        config[:hackerone][:headers] = { Authorization: "Basic #{basic}" }
        Hackerone::Programs.sync(results, config[:hackerone])
      else
        Utilities.log_warn('Hackerone - Authentication parameter missing, skipped')
      end

      # -- BUGCROWD
      if config[:bugcrowd][:email] && config[:bugcrowd][:password]
        bc_authenticated = Bugcrowd.authenticate(config[:bugcrowd])
        Utilities.log_warn('Bugcrowd - Authentication Failed') unless bc_authenticated
        Bugcrowd::Programs.sync(results['Bugcrowd']) if bc_authenticated
      else
        Utilities.log_warn('Bugcrowd - Authentication parameter missing, skipped')
      end

      # -- YESWEHACK
      if config[:yeswehack][:email] && config[:yeswehack][:password] && config[:yeswehack][:otp]
        jwt = YesWeHack.authenticate(config[:yeswehack])
        Utilities.log_warn('YesWeHack - Authentication Failed') unless jwt

        config[:yeswehack][:headers] = { 'Content-Type' => 'application/json', Authorization: "Bearer #{jwt}" }
        YesWeHack::Programs.sync(results, config[:yeswehack]) if jwt
      else
        Utilities.log_warn('YesWeHack - Authentication parameter missing, skipped')
      end

      # -- INTIGRITI
      if config[:intigriti][:token]
        config[:intigriti][:headers] = { Authorization: "Bearer #{config[:intigriti][:token]}" }
        Intigriti::Programs.sync(results, config[:intigriti])
      else
        Utilities.log_warn('Intigriti - Authentication parameter missing, skipped')
      end

      File.open('extract.json', 'w') { |f| f.write(JSON.pretty_generate(results)) }
    end
  end
end
