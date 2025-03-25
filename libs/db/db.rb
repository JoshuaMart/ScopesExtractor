# frozen_string_literal: true

require 'json'
require 'fileutils'

module ScopesExtractor
  # DB module provides a simple flat-file JSON database for storing and retrieving program data
  module DB
    # Path to the JSON database file
    DB_FILE = File.join(__dir__, 'db.json')

    # Loads program data from the JSON database file
    # @return [Hash] Program data from the database, empty hash if the file doesn't exist or is invalid
    def self.load
      return {} unless File.exist?(DB_FILE)

      file_content = File.read(DB_FILE)
      JSON.parse(file_content)
    rescue JSON::ParserError
      {}
    end

    # Saves program data to the JSON database file
    # @param data [Hash] Program data to save
    # @return [Integer] Number of bytes written to the file
    def self.save(data)
      File.write(DB_FILE, JSON.pretty_generate(data))
    end
  end
end
