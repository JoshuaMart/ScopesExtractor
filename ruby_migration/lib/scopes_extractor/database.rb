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

    def self.cleanup_old_history
      retention_days = Config.history_retention_days
      cutoff_date = Time.now - (retention_days * 24 * 3600)

      deleted_count = ScopesExtractor.db[:history]
                                     .where(Sequel[:created_at] < cutoff_date)
                                     .delete

      return unless deleted_count.positive?

      ScopesExtractor.logger.info "Cleaned up #{deleted_count} old history entries (older than #{retention_days} days)"
    end
  end
end
