# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'time'

module ScopesExtractor
  # DB module provides a simple flat-file JSON database for storing and retrieving program data
  module DB
    # Path to the JSON database file
    DB_FILE = File.join(__dir__, 'db.json')
    # Path to the JSON history file
    HISTORY_FILE = File.join(__dir__, 'history.json')

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

    # Loads change history from the JSON history file
    # @return [Array] Array of change history entries, empty array if the file doesn't exist or is invalid
    def self.load_history
      return [] unless File.exist?(HISTORY_FILE)

      file_content = File.read(HISTORY_FILE)
      JSON.parse(file_content)
    rescue JSON::ParserError
      []
    end

    # Saves a change to the history file
    # @param platform [String] Platform name (e.g., 'YesWeHack')
    # @param program [String] Program title
    # @param change_type [String] Type of change ('add_program', 'remove_program', 'add_scope', 'remove_scope')
    # @param scope_type [String, nil] Scope type ('in' or 'out') for scope changes, nil for program changes
    # @param category [String, nil] Category for scope changes, nil for program changes
    # @param value [String] Value of scope or program name
    # @param scopes [Hash, nil] Optional scopes data for removed programs
    # @return [Integer] Number of bytes written to the file
    def self.save_change(platform, program, change_type, scope_type, category, value, scopes = nil)
      history = load_history

      # Create a new entry
      entry = {
        'timestamp' => Time.now.utc.iso8601,
        'platform' => platform,
        'program' => program,
        'change_type' => change_type,
        'scope_type' => scope_type,
        'category' => category,
        'value' => value
      }

      # Add scopes if provided (typically for removed programs)
      entry['scopes'] = scopes if scopes

      history << entry

      # Clean up old entries based on retention policy
      retention_days = Config.load.dig(:history, :retention_days) || 30
      cutoff_time = (Time.now.utc - (retention_days * 24 * 60 * 60)).iso8601
      history = history.select { |h| h['timestamp'] >= cutoff_time }

      File.write(HISTORY_FILE, JSON.pretty_generate(history))
    end

    # Gets recent changes from the history file
    # @param hours [Integer] Number of hours to look back
    # @param filters [Hash] Optional filters for the changes (platform, program, change_type)
    # @return [Array] Array of recent changes matching the criteria
    def self.get_recent_changes(hours = 48, filters = {})
      history = load_history
      cutoff_time = (Time.now.utc - (hours * 60 * 60)).iso8601

      # Filter by time first
      filtered = history.select { |entry| entry['timestamp'] >= cutoff_time }

      # Apply additional filters if specified
      filters.each do |key, value|
        filtered = filtered.select { |entry| entry[key.to_s] == value }
      end

      filtered
    end
  end
end
