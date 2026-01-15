# frozen_string_literal: true

require 'spec_helper'
require 'support/mock_platform'

RSpec.describe ScopesExtractor::SyncManager do
  let(:diff_engine) { instance_double(ScopesExtractor::DiffEngine) }
  let(:notifier) { instance_double(ScopesExtractor::Notifiers::Discord) }
  let(:sync_manager) { described_class.new(diff_engine: diff_engine, notifier: notifier) }

  let(:mock_platform) do
    MockPlatform.new(name: 'TestPlatform', programs: [])
  end

  before do
    ScopesExtractor::Database.connect
    ScopesExtractor::Database.reset
    ScopesExtractor::Database.migrate

    allow(diff_engine).to receive(:process_program)
    allow(diff_engine).to receive(:process_removed_programs)
    allow(notifier).to receive(:notify_error)
    allow(ScopesExtractor::Database).to receive(:cleanup_old_history)
  end

  describe '#run' do
    context 'when no platforms match' do
      it 'logs a warning and returns' do
        expect(ScopesExtractor.logger).to receive(:warn).with(/No enabled platforms/)
        sync_manager.run(platform_name: 'nonexistent')
      end
    end

    context 'when platforms match' do
      before do
        allow(sync_manager).to receive(:targets_for).and_return([mock_platform])
      end

      it 'cleans up old history before sync' do
        expect(ScopesExtractor::Database).to receive(:cleanup_old_history)
        sync_manager.run
      end

      it 'logs synchronization start and completion' do
        expect(ScopesExtractor.logger).to receive(:info).with(/Starting synchronization/)
        expect(ScopesExtractor.logger).to receive(:info).with(/Starting sync/).at_least(:once)
        expect(ScopesExtractor.logger).to receive(:info).with(/First sync detected/).at_least(:once)
        expect(ScopesExtractor.logger).to receive(:info).with(/Synchronization completed/)
        sync_manager.run
      end
    end
  end

  describe '#targets_for' do
    let(:platform1) { MockPlatform.new(name: 'YesWeHack') }
    let(:platform2) { MockPlatform.new(name: 'HackerOne') }

    before do
      sync_manager.instance_variable_set(:@platforms, [platform1, platform2])
    end

    context 'when platform_name is nil' do
      it 'returns all platforms' do
        expect(sync_manager.targets_for(nil)).to eq([platform1, platform2])
      end
    end

    context 'when platform_name is specified' do
      it 'returns matching platform (case insensitive)' do
        targets = sync_manager.targets_for('yeswehack')
        expect(targets).to eq([platform1])
      end

      it 'handles underscores in platform names' do
        targets = sync_manager.targets_for('yes_we_hack')
        expect(targets).to eq([platform1])
      end

      it 'returns empty array when no match' do
        targets = sync_manager.targets_for('nonexistent')
        expect(targets).to be_empty
      end
    end
  end

  describe 'platform synchronization' do
    let(:program1) do
      ScopesExtractor::Models::Program.new(
        slug: 'program-1',
        platform: 'testplatform',
        name: 'Program 1',
        bounty: true,
        scopes: []
      )
    end

    let(:program2) do
      ScopesExtractor::Models::Program.new(
        slug: 'program-2',
        platform: 'testplatform',
        name: 'Program 2',
        bounty: false,
        scopes: []
      )
    end

    before do
      platform_with_programs = MockPlatform.new(name: 'TestPlatform', programs: [program1, program2])
      allow(sync_manager).to receive(:targets_for).and_return([platform_with_programs])
    end

    it 'processes each program through DiffEngine' do
      expect(diff_engine).to receive(:process_program).with('testplatform', program1, skip_notifications: true)
      expect(diff_engine).to receive(:process_program).with('testplatform', program2, skip_notifications: true)
      sync_manager.run
    end

    it 'handles removed programs' do
      expect(diff_engine).to receive(:process_removed_programs)
        .with('testplatform', %w[program-1 program-2], skip_notifications: true)
      sync_manager.run
    end

    context 'when program is excluded' do
      before do
        allow(ScopesExtractor::Config).to receive(:excluded?).with('testplatform', 'program-1').and_return(true)
        allow(ScopesExtractor::Config).to receive(:excluded?).with('testplatform', 'program-2').and_return(false)
      end

      it 'skips excluded program' do
        expect(diff_engine).not_to receive(:process_program).with('testplatform', program1, anything)
        expect(diff_engine).to receive(:process_program).with('testplatform', program2, skip_notifications: true)
        sync_manager.run
      end

      it 'excludes program from removed programs check' do
        expect(diff_engine).to receive(:process_removed_programs)
          .with('testplatform', ['program-2'], skip_notifications: true)
        sync_manager.run
      end

      it 'logs the skip' do
        expect(ScopesExtractor.logger).to receive(:debug).with(/Skipping excluded program: program-1/)
        sync_manager.run
      end
    end

    context 'when program processing fails' do
      before do
        allow(diff_engine).to receive(:process_program).with('testplatform', program1, skip_notifications: true)
                                                       .and_raise(StandardError.new('Test error'))
        allow(diff_engine).to receive(:process_program).with('testplatform', program2, skip_notifications: true)
      end

      it 'logs the error and continues' do
        expect(ScopesExtractor.logger).to receive(:error).with(/Failed to process program program-1/)
        expect(notifier).to receive(:notify_error).with('Program Sync Error', anything)
        sync_manager.run
      end
    end

    context 'when platform sync fails' do
      before do
        failing_platform = MockPlatform.new(name: 'TestPlatform', programs: [])
        allow(failing_platform).to receive(:fetch_programs).and_raise(StandardError.new('API error'))
        allow(sync_manager).to receive(:targets_for).and_return([failing_platform])
      end

      it 'logs the error and notifies' do
        expect(ScopesExtractor.logger).to receive(:error).with(/Sync failed: API error/)
        expect(notifier).to receive(:notify_error).with('Platform Sync Error', /TestPlatform.*API error/)
        sync_manager.run
      end

      it 'does not process programs when fetch fails' do
        expect(diff_engine).not_to receive(:process_program)
        expect(diff_engine).not_to receive(:process_removed_programs)
        sync_manager.run
      end
    end

    context 'when valid_access? fails' do
      before do
        platform = MockPlatform.new(name: 'TestPlatform', programs: [])
        allow(platform).to receive(:valid_access?).and_return(false)
        allow(sync_manager).to receive(:targets_for).and_return([platform])
      end

      it 'logs access validation error' do
        expect(ScopesExtractor.logger).to receive(:error).with(/Access validation failed/)
        sync_manager.run
      end

      it 'notifies about access error' do
        expect(notifier).to receive(:notify_error).with('Platform Access Error', /TestPlatform.*Access validation failed/)
        sync_manager.run
      end

      it 'does not call fetch_programs' do
        platform = MockPlatform.new(name: 'TestPlatform', programs: [])
        allow(platform).to receive(:valid_access?).and_return(false)
        allow(sync_manager).to receive(:targets_for).and_return([platform])

        expect(platform).not_to receive(:fetch_programs)
        sync_manager.run
      end

      it 'does not process programs' do
        expect(diff_engine).not_to receive(:process_program)
        expect(diff_engine).not_to receive(:process_removed_programs)
        sync_manager.run
      end
    end

    context 'when valid_access? succeeds' do
      before do
        platform = MockPlatform.new(name: 'TestPlatform', programs: [])
        allow(platform).to receive(:valid_access?).and_return(true)
        allow(sync_manager).to receive(:targets_for).and_return([platform])
      end

      it 'calls valid_access? before fetching programs' do
        platform = MockPlatform.new(name: 'TestPlatform', programs: [])
        allow(sync_manager).to receive(:targets_for).and_return([platform])

        expect(platform).to receive(:valid_access?).ordered.and_return(true)
        expect(platform).to receive(:fetch_programs).ordered.and_return([])

        sync_manager.run
      end
    end

    context 'when platform sync fails and database has existing programs' do
      before do
        # Setup failing platform
        failing_platform = MockPlatform.new(name: 'TestPlatform', programs: [])
        allow(failing_platform).to receive(:valid_access?).and_return(true)
        allow(failing_platform).to receive(:fetch_programs).and_raise(StandardError.new('API error'))
        allow(sync_manager).to receive(:targets_for).and_return([failing_platform])

        # Insert existing program in database
        db = ScopesExtractor.db
        program_id = db[:programs].insert(
          slug: 'existing-program',
          platform: 'testplatform',
          name: 'Existing Program',
          bounty: true,
          last_updated: Time.now
        )
        db[:scopes].insert(
          program_id: program_id,
          value: 'example.com',
          type: 'web',
          is_in_scope: true,
          created_at: Time.now
        )
      end

      it 'preserves existing programs and scopes when fetch fails' do
        db = ScopesExtractor.db

        # Verify data exists before sync
        expect(db[:programs].count).to eq(1)
        expect(db[:scopes].count).to eq(1)

        # Run sync with failing platform
        sync_manager.run

        # Verify data is still intact after failed sync
        expect(db[:programs].count).to eq(1)
        expect(db[:scopes].count).to eq(1)

        program = db[:programs].first
        expect(program[:slug]).to eq('existing-program')
        scope = db[:scopes].first
        expect(scope[:value]).to eq('example.com')
      end
    end

    context 'when it is the first sync for a platform (empty database)' do
      before do
        platform_with_programs = MockPlatform.new(name: 'TestPlatform', programs: [program1, program2])
        allow(sync_manager).to receive(:targets_for).and_return([platform_with_programs])
      end

      it 'detects first sync and logs it' do
        allow(ScopesExtractor.logger).to receive(:info) # Allow other log messages
        expect(ScopesExtractor.logger).to receive(:info).with(/First sync detected - notifications will be skipped/)
        sync_manager.run
      end

      it 'passes skip_notifications: true to process_program' do
        expect(diff_engine).to receive(:process_program).with('testplatform', program1, skip_notifications: true)
        expect(diff_engine).to receive(:process_program).with('testplatform', program2, skip_notifications: true)
        sync_manager.run
      end

      it 'passes skip_notifications: true to process_removed_programs' do
        expect(diff_engine).to receive(:process_removed_programs)
          .with('testplatform', %w[program-1 program-2], skip_notifications: true)
        sync_manager.run
      end
    end

    context 'when it is not the first sync for a platform (database has programs)' do
      before do
        # Insert existing program in database for this platform
        db = ScopesExtractor.db
        db[:programs].insert(
          slug: 'existing-program',
          platform: 'testplatform',
          name: 'Existing Program',
          bounty: true,
          last_updated: Time.now
        )

        platform_with_programs = MockPlatform.new(name: 'TestPlatform', programs: [program1, program2])
        allow(sync_manager).to receive(:targets_for).and_return([platform_with_programs])
      end

      it 'does not log first sync message' do
        expect(ScopesExtractor.logger).not_to receive(:info).with(/First sync detected/)
        allow(ScopesExtractor.logger).to receive(:info) # Allow other log messages
        sync_manager.run
      end

      it 'passes skip_notifications: false to process_program' do
        expect(diff_engine).to receive(:process_program).with('testplatform', program1, skip_notifications: false)
        expect(diff_engine).to receive(:process_program).with('testplatform', program2, skip_notifications: false)
        sync_manager.run
      end

      it 'passes skip_notifications: false to process_removed_programs' do
        expect(diff_engine).to receive(:process_removed_programs)
          .with('testplatform', anything, skip_notifications: false)
        sync_manager.run
      end
    end
  end
end
# rubocop:enable RSpec/IndexedLet
