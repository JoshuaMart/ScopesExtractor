# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'

RSpec.describe ScopesExtractor::Database do
  let(:test_db_path) { File.join(ScopesExtractor.root, 'tmp', 'test.db') }

  before do
    FileUtils.mkdir_p(File.dirname(test_db_path))
    allow(ScopesExtractor::Config).to receive(:database_path).and_return('tmp/test.db')
  end

  after do
    FileUtils.rm_f(test_db_path)
  end

  describe '.connect' do
    it 'establishes a database connection' do
      db = described_class.connect
      expect(db).to be_a(Sequel::Database)
      expect(ScopesExtractor.db).to eq(db)
    end

    it 'creates the database directory if it does not exist' do
      described_class.connect
      expect(File.directory?(File.dirname(test_db_path))).to be true
    end

    it 'logs the connection info' do
      expect(ScopesExtractor.logger).to receive(:info).with(/Connected to database/)
      described_class.connect
    end
  end

  describe '.migrate' do
    before do
      described_class.connect
    end

    it 'runs migrations successfully' do
      expect(ScopesExtractor.logger).to receive(:info).with(/Running database migrations/)
      expect(ScopesExtractor.logger).to receive(:info).with(/Database migrations completed/)
      described_class.migrate
    end

    it 'creates all required tables' do
      described_class.migrate

      expect(ScopesExtractor.db.tables).to include(:programs)
      expect(ScopesExtractor.db.tables).to include(:scopes)
      expect(ScopesExtractor.db.tables).to include(:history)
      expect(ScopesExtractor.db.tables).to include(:ignored_assets)
    end

    it 'logs when database is already up to date' do
      described_class.migrate
      expect(ScopesExtractor.logger).to receive(:info).with('Database is up to date')
      described_class.migrate
    end
  end

  describe '.cleanup_old_history' do
    before do
      described_class.connect
      described_class.migrate
    end

    it 'deletes history entries older than retention period' do
      old_date = Time.now - (31 * 24 * 3600)
      recent_date = Time.now - (5 * 24 * 3600)

      ScopesExtractor.db[:history].insert(
        event_type: 'add_program',
        created_at: old_date
      )
      ScopesExtractor.db[:history].insert(
        event_type: 'add_program',
        created_at: recent_date
      )

      described_class.cleanup_old_history

      expect(ScopesExtractor.db[:history].count).to eq(1)
      remaining = ScopesExtractor.db[:history].first
      expect(remaining[:created_at]).to be > old_date
    end

    it 'logs the number of deleted entries' do
      old_date = Time.now - (31 * 24 * 3600)
      ScopesExtractor.db[:history].insert(
        event_type: 'add_program',
        created_at: old_date
      )

      expect(ScopesExtractor.logger).to receive(:info).with(/Cleaned up 1 old history entries/)
      described_class.cleanup_old_history
    end

    it 'does not log when no entries are deleted' do
      expect(ScopesExtractor.logger).not_to receive(:info).with(/Cleaned up/)
      described_class.cleanup_old_history
    end
  end

  describe '.reset' do
    before do
      described_class.connect
      described_class.migrate
    end

    it 'drops all tables' do
      described_class.reset
      expect(ScopesExtractor.db.tables).to be_empty
    end

    it 'logs the reset operation' do
      expect(ScopesExtractor.logger).to receive(:warn).with('Resetting database...')
      expect(ScopesExtractor.logger).to receive(:info).with(/Database reset complete/)
      described_class.reset
    end
  end
end
