# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'

  # Generate JSON format for Qlty coverage upload
  formatter SimpleCov::Formatter::JSONFormatter if ENV['CI']
end

require_relative '../lib/scopes_extractor'

# Disable logger output during tests
ScopesExtractor.logger.level = Logger::FATAL

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true
  config.default_formatter = 'doc' if config.files_to_run.one?
  config.order = :random
  Kernel.srand config.seed

  # Clean up test database after each test
  config.after do
    next unless ScopesExtractor.db

    begin
      ScopesExtractor.db.tables.each do |table|
        ScopesExtractor.db[table].delete
      rescue Sequel::DatabaseError
        # Ignore errors on readonly databases or missing tables
      end
    rescue StandardError => e
      warn "Failed to clean test database: #{e.message}"
    end
  end
end
