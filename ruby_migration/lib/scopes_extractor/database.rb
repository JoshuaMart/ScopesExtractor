# frozen_string_literal: true

require 'sequel'
require 'fileutils'

module ScopesExtractor
  class Database
    def self.migrate
      Sequel.extension :migration
      migrations_path = File.expand_path('../../db/migrations', __dir__)

      # Ensure db directory exists
      FileUtils.mkdir_p('db')

      ScopesExtractor.logger.info 'Running migrations...'
      Sequel::Migrator.run(ScopesExtractor.db, migrations_path)
      ScopesExtractor.logger.info 'Database is up to date.'
    end
  end
end
