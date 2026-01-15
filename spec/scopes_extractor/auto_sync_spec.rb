# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::AutoSync do
  let(:sync_manager) { instance_double('SyncManager') } # rubocop:disable RSpec/VerifiedDoubleReference
  let(:auto_sync) { described_class.new(sync_manager) }

  before do
    allow(ScopesExtractor::Config).to receive(:sync).and_return({ delay: 1 })
    allow(sync_manager).to receive(:run)
    # Allow all logger calls to prevent issues with threads
    allow(ScopesExtractor.logger).to receive(:info)
    allow(ScopesExtractor.logger).to receive(:error)
    allow(ScopesExtractor.logger).to receive(:debug)
  end

  after do
    auto_sync.stop if auto_sync.running?
  end

  describe '#initialize' do
    it 'stores the sync manager' do
      expect(auto_sync.instance_variable_get(:@sync_manager)).to eq(sync_manager)
    end

    it 'initializes as not running' do
      expect(auto_sync.running?).to be false
    end

    it 'initializes thread as nil' do
      expect(auto_sync.instance_variable_get(:@thread)).to be_nil
    end
  end

  describe '#start' do
    it 'sets running to true' do
      auto_sync.start
      expect(auto_sync.running?).to be true
    end

    it 'logs the start message' do
      expect(ScopesExtractor.logger).to receive(:info).with('Starting auto-sync with 1s delay')
      expect(ScopesExtractor.logger).to receive(:info).with('[AutoSync] Starting scheduled synchronization').at_least(:once)
      expect(ScopesExtractor.logger).to receive(:info).with('[AutoSync] Scheduled synchronization completed').at_least(:once)
      auto_sync.start
      sleep 0.1 # Give thread time to log
    end

    it 'performs initial sync immediately' do
      expect(sync_manager).to receive(:run).at_least(:once)
      auto_sync.start
      sleep 0.1 # Give thread time to start
    end

    it 'creates a background thread' do
      auto_sync.start
      expect(auto_sync.instance_variable_get(:@thread)).to be_a(Thread)
      expect(auto_sync.instance_variable_get(:@thread)).to be_alive
    end

    it 'does not start if already running' do
      auto_sync.start
      thread1 = auto_sync.instance_variable_get(:@thread)

      auto_sync.start
      thread2 = auto_sync.instance_variable_get(:@thread)

      expect(thread1).to eq(thread2)
    end

    it 'performs sync repeatedly with configured delay' do
      allow(ScopesExtractor::Config).to receive(:sync).and_return({ delay: 0.1 })

      call_count = 0
      allow(sync_manager).to receive(:run) do
        call_count += 1
      end

      auto_sync.start
      sleep 0.35 # Should perform ~3 syncs (initial + 2 more)
      auto_sync.stop

      expect(call_count).to be >= 2
    end
  end

  describe '#stop' do
    context 'when auto-sync is running' do
      before do
        auto_sync.start
        sleep 0.1 # Give thread time to start
      end

      it 'sets running to false' do
        auto_sync.stop
        expect(auto_sync.running?).to be false
      end

      it 'logs the stop message' do
        expect(ScopesExtractor.logger).to receive(:info).with('Stopping auto-sync...')
        auto_sync.stop
      end

      it 'waits for thread to finish' do
        thread = auto_sync.instance_variable_get(:@thread)
        expect(thread).to receive(:join).with(5).and_call_original
        auto_sync.stop
      end

      it 'sets thread to nil' do
        auto_sync.stop
        expect(auto_sync.instance_variable_get(:@thread)).to be_nil
      end

      it 'stops the background thread' do
        thread = auto_sync.instance_variable_get(:@thread)
        auto_sync.stop
        sleep 0.1
        expect(thread).not_to be_alive
      end
    end

    context 'when auto-sync is not running' do
      it 'does nothing' do
        expect(ScopesExtractor.logger).not_to receive(:info)
        auto_sync.stop
      end

      it 'returns without error' do
        expect { auto_sync.stop }.not_to raise_error
      end
    end
  end

  describe '#running?' do
    it 'returns false when not started' do
      expect(auto_sync.running?).to be false
    end

    it 'returns true when started' do
      auto_sync.start
      expect(auto_sync.running?).to be true
    end

    it 'returns false after stopped' do
      auto_sync.start
      auto_sync.stop
      expect(auto_sync.running?).to be false
    end
  end

  describe '#perform_sync' do
    it 'logs start and completion messages' do
      expect(ScopesExtractor.logger).to receive(:info).with('[AutoSync] Starting scheduled synchronization')
      expect(ScopesExtractor.logger).to receive(:info).with('[AutoSync] Scheduled synchronization completed')
      auto_sync.send(:perform_sync)
    end

    it 'calls sync_manager.run' do
      expect(sync_manager).to receive(:run)
      auto_sync.send(:perform_sync)
    end

    context 'when sync fails' do
      let(:error) { StandardError.new('Sync error') }

      before do
        allow(sync_manager).to receive(:run).and_raise(error)
        allow(error).to receive(:backtrace).and_return(['line 1', 'line 2'])
      end

      it 'logs error message' do
        expect(ScopesExtractor.logger).to receive(:info).with('[AutoSync] Starting scheduled synchronization')
        expect(ScopesExtractor.logger).to receive(:error).with('[AutoSync] Sync failed: Sync error')
        expect(ScopesExtractor.logger).to receive(:debug).with("line 1\nline 2")
        auto_sync.send(:perform_sync)
      end

      it 'does not raise the error' do
        allow(ScopesExtractor.logger).to receive(:info)
        allow(ScopesExtractor.logger).to receive(:error)
        allow(ScopesExtractor.logger).to receive(:debug)
        expect { auto_sync.send(:perform_sync) }.not_to raise_error
      end

      it 'continues to run subsequent syncs' do
        allow(ScopesExtractor::Config).to receive(:sync).and_return({ delay: 0.1 })

        # First call fails, subsequent calls succeed
        call_count = 0
        allow(sync_manager).to receive(:run) do
          call_count += 1
          raise error if call_count == 1
        end

        allow(ScopesExtractor.logger).to receive(:info)
        allow(ScopesExtractor.logger).to receive(:error)
        allow(ScopesExtractor.logger).to receive(:debug)

        auto_sync.start
        sleep 0.35 # Should attempt multiple syncs
        auto_sync.stop

        expect(call_count).to be >= 2
      end
    end
  end

  describe 'thread safety' do
    it 'handles rapid start/stop cycles' do
      5.times do
        auto_sync.start
        sleep 0.05
        auto_sync.stop
      end

      expect(auto_sync.running?).to be false
      expect(auto_sync.instance_variable_get(:@thread)).to be_nil
    end

    it 'breaks loop when stopped during sleep' do
      allow(ScopesExtractor::Config).to receive(:sync).and_return({ delay: 10 })

      auto_sync.start
      sleep 0.1
      auto_sync.stop

      expect(auto_sync.running?).to be false
    end
  end
end
