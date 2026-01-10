# frozen_string_literal: true

module ScopesExtractor
  module Database
    class << self
      def connect
        database_path = resolve_database_path
        ensure_db_directory(database_path)

        ScopesExtractor.db = Sequel.sqlite(database_path)
        ScopesExtractor.logger.info "Connected to database: #{database_path}".green

        ScopesExtractor.db
      end

      def migrate
        Sequel.extension :migration
        migrations_path = File.join(ScopesExtractor.root, 'db', 'migrations')

        if Sequel::Migrator.is_current?(ScopesExtractor.db, migrations_path)
          ScopesExtractor.logger.info 'Database is up to date'
        else
          ScopesExtractor.logger.info 'Running database migrations...'
          Sequel::Migrator.run(ScopesExtractor.db, migrations_path)
          ScopesExtractor.logger.info 'Database migrations completed'.green
        end
      end

      def cleanup_old_history
        retention_days = Config.history_retention_days
        cutoff_date = Time.now - (retention_days * 24 * 3600)

        deleted_count = ScopesExtractor.db[:history]
                                       .where(Sequel[:created_at] < cutoff_date)
                                       .delete

        return unless deleted_count.positive?

        message = "Cleaned up #{deleted_count} old history entries (older than #{retention_days} days)"
        ScopesExtractor.logger.info message
      end

      def reset
        ScopesExtractor.logger.warn 'Resetting database...'
        ScopesExtractor.db.tables.each do |table|
          ScopesExtractor.db.drop_table(table)
        end
        ScopesExtractor.logger.info 'Database reset complete'.green
      end

      private

      def resolve_database_path
        path = Config.database_path
        path.start_with?('/') ? path : File.join(ScopesExtractor.root, path)
      end

      def ensure_db_directory(database_path)
        db_dir = File.dirname(database_path)
        FileUtils.mkdir_p(db_dir) unless File.directory?(db_dir)
      end
    end
  end
end
