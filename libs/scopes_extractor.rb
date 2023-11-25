# frozen_string_literal: true

require 'json'
require 'rotp'

Dir[File.join(__dir__, 'platforms', '**', '*.rb')].sort.each { |file| require file }
Dir[File.join(__dir__, 'utilities', '*.rb')].sort.each { |file| require file }

module ScopesExtractor
  # Extaact
  class Extract
    def initialize
      @config = Config.load
    end

    def run
      jwt_ywh = YesWeHack.authenticate(@config[:yeswehack])
      puts "JWT YesWeHack: #{jwt_ywh}"
    end
  end
end
