# frozen_string_literal: true

require 'dotenv'
require 'json'
require 'rotp'
require 'typhoeus'

require_relative 'scopes_extractor/utilities'
require_relative 'scopes_extractor/http_client'
require_relative 'scopes_extractor/platforms/bugcrowd/cookie'
require_relative 'scopes_extractor/platforms/bugcrowd/programs'
require_relative 'scopes_extractor/platforms/hackerone/programs'
require_relative 'scopes_extractor/platforms/intigriti/token'
require_relative 'scopes_extractor/platforms/intigriti/programs'
require_relative 'scopes_extractor/platforms/yeswehack/jwt'
require_relative 'scopes_extractor/platforms/yeswehack/programs'

# Class entrypoint to start the extractions and initializes all the objects
class ScopesExtractor
  attr_reader :options
  attr_accessor :results

  def initialize(options = {})
    @options = options
    @results = {}
  end

  def extract
    Utilities.log_fatal('[-] The file containing the credentials is mandatory') unless options[:credz_file]
    Dotenv.load(options[:credz_file])

    if options[:yeswehack]
      jwt = YesWeHack::Auth.jwt
      results['YesWeHack'] = {}

      YesWeHack::Programs.sync(results['YesWeHack'], options, jwt)
    end

    if options[:intigriti]
      token = Intigriti::Auth.token
      results['Intigriti'] = {}

      Intigriti::Programs.sync(results['Intigriti'], options, token)
    end

    if options[:bugcrowd]
      cookie = Bugcrowd::Auth.cookie
      results['Bugcrowd'] = {}

      Bugcrowd::Programs.sync(results['Bugcrowd'], options, cookie)
    end

    if options[:hackerone]
      results['Hackerone'] = {}

      Hackerone::Programs.sync(results['Hackerone'], options)
    end

    results
  end
end
