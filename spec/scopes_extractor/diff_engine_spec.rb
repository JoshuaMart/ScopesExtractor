# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::DiffEngine do
  let(:notifier) { instance_double(ScopesExtractor::Notifiers::Discord) }
  let(:diff_engine) { described_class.new(notifier: notifier) }

  before do
    ScopesExtractor::Database.connect

    # Reset and migrate for clean state
    ScopesExtractor::Database.reset
    ScopesExtractor::Database.migrate

    # Stub all notifier methods
    allow(notifier).to receive(:notify_new_program)
    allow(notifier).to receive(:notify_removed_program)
    allow(notifier).to receive(:notify_new_scope)
    allow(notifier).to receive(:notify_removed_scope)
    allow(notifier).to receive(:notify_ignored_asset)
  end

  describe '#process_program' do
    context 'when program is new' do
      it 'inserts the program into database' do
        program = ScopesExtractor::Models::Program.new(
          slug: 'test-program',
          platform: 'yeswehack',
          name: 'Test Program',
          bounty: true,
          scopes: []
        )

        diff_engine.process_program('yeswehack', program)

        db_program = ScopesExtractor.db[:programs].where(slug: 'test-program', platform: 'yeswehack').first
        expect(db_program).not_to be_nil
        expect(db_program[:name]).to eq('Test Program')
        expect(db_program[:bounty]).to be true
      end

      it 'notifies about new program' do
        program = ScopesExtractor::Models::Program.new(
          slug: 'test-program',
          platform: 'yeswehack',
          name: 'Test Program',
          bounty: true,
          scopes: []
        )

        expect(notifier).to receive(:notify_new_program).with('yeswehack', 'Test Program', 'test-program')
        diff_engine.process_program('yeswehack', program)
      end

      it 'logs the event' do
        program = ScopesExtractor::Models::Program.new(
          slug: 'test-program',
          platform: 'yeswehack',
          name: 'Test Program',
          bounty: true,
          scopes: []
        )

        diff_engine.process_program('yeswehack', program)

        history = ScopesExtractor.db[:history].where(event_type: 'add_program').first
        expect(history).not_to be_nil
        expect(history[:platform_name]).to eq('yeswehack')
        expect(history[:details]).to eq('Brand new program discovered')
      end
    end

    context 'when program already exists' do
      before do
        ScopesExtractor.db[:programs].insert(
          slug: 'existing-program',
          platform: 'yeswehack',
          name: 'Old Name',
          bounty: false,
          last_updated: Time.now
        )
      end

      it 'updates program name and bounty if changed' do
        program = ScopesExtractor::Models::Program.new(
          slug: 'existing-program',
          platform: 'yeswehack',
          name: 'New Name',
          bounty: true,
          scopes: []
        )

        diff_engine.process_program('yeswehack', program)

        db_program = ScopesExtractor.db[:programs].where(slug: 'existing-program').first
        expect(db_program[:name]).to eq('New Name')
        expect(db_program[:bounty]).to be true
      end

      it 'does not update if nothing changed' do
        program = ScopesExtractor::Models::Program.new(
          slug: 'existing-program',
          platform: 'yeswehack',
          name: 'Old Name',
          bounty: false,
          scopes: []
        )

        old_updated = ScopesExtractor.db[:programs].where(slug: 'existing-program').first[:last_updated]
        sleep 0.1
        diff_engine.process_program('yeswehack', program)
        new_updated = ScopesExtractor.db[:programs].where(slug: 'existing-program').first[:last_updated]

        expect(new_updated).to eq(old_updated)
      end
    end

    context 'when program has scopes' do
      it 'adds new scopes' do
        program = ScopesExtractor::Models::Program.new(
          slug: 'test-program',
          platform: 'yeswehack',
          name: 'Test Program',
          bounty: true,
          scopes: [
            ScopesExtractor::Models::Scope.new(value: '*.example.com', type: 'web', is_in_scope: true)
          ]
        )

        diff_engine.process_program('yeswehack', program)

        scopes = ScopesExtractor.db[:scopes].all
        expect(scopes.count).to eq(1)
        expect(scopes.first[:value]).to eq('*.example.com')
        expect(scopes.first[:type]).to eq('web')
        expect(scopes.first[:is_in_scope]).to be true
      end

      it 'normalizes scopes before adding' do
        program = ScopesExtractor::Models::Program.new(
          slug: 'test-program',
          platform: 'yeswehack',
          name: 'Test Program',
          bounty: true,
          scopes: [
            ScopesExtractor::Models::Scope.new(value: 'EXAMPLE.COM', type: 'web', is_in_scope: true)
          ]
        )

        diff_engine.process_program('yeswehack', program)

        scopes = ScopesExtractor.db[:scopes].all
        expect(scopes.first[:value]).to eq('example.com')
      end

      it 'notifies about new scopes' do
        program = ScopesExtractor::Models::Program.new(
          slug: 'test-program',
          platform: 'yeswehack',
          name: 'Test Program',
          bounty: true,
          scopes: [
            ScopesExtractor::Models::Scope.new(value: '*.example.com', type: 'web', is_in_scope: true)
          ]
        )

        expect(notifier).to receive(:notify_new_scope).with('yeswehack', 'Test Program', '*.example.com', 'web')
        diff_engine.process_program('yeswehack', program)
      end

      it 'ignores invalid scopes' do
        program = ScopesExtractor::Models::Program.new(
          slug: 'test-program',
          platform: 'yeswehack',
          name: 'Test Program',
          bounty: true,
          scopes: [
            ScopesExtractor::Models::Scope.new(value: 'invalid', type: 'web', is_in_scope: true)
          ]
        )

        expect(notifier).to receive(:notify_ignored_asset)
        diff_engine.process_program('yeswehack', program)

        scopes = ScopesExtractor.db[:scopes].all
        expect(scopes.count).to eq(0)

        ignored = ScopesExtractor.db[:ignored_assets].all
        expect(ignored.count).to eq(1)
      end
    end
  end

  describe '#process_removed_programs' do
    before do
      ScopesExtractor.db[:programs].insert(
        slug: 'program-1',
        platform: 'yeswehack',
        name: 'Program 1',
        bounty: true,
        last_updated: Time.now
      )
      ScopesExtractor.db[:programs].insert(
        slug: 'program-2',
        platform: 'yeswehack',
        name: 'Program 2',
        bounty: false,
        last_updated: Time.now
      )
    end

    it 'removes programs not in fetched list' do
      diff_engine.process_removed_programs('yeswehack', ['program-1'])

      programs = ScopesExtractor.db[:programs].where(platform: 'yeswehack').all
      expect(programs.count).to eq(1)
      expect(programs.first[:slug]).to eq('program-1')
    end

    it 'notifies about removed programs' do
      expect(notifier).to receive(:notify_removed_program).with('yeswehack', 'Program 2', 'program-2')
      diff_engine.process_removed_programs('yeswehack', ['program-1'])
    end

    it 'logs removal events' do
      diff_engine.process_removed_programs('yeswehack', ['program-1'])

      history = ScopesExtractor.db[:history].where(event_type: 'remove_program').first
      expect(history).not_to be_nil
      expect(history[:details]).to eq('Program no longer available')
    end
  end
end
