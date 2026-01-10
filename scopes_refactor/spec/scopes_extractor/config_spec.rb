# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Config do
  describe '.load' do
    it 'loads the configuration file' do
      config = described_class.load
      expect(config).to be_a(Hash)
      expect(config).to have_key(:app)
    end
  end

  describe '.reload' do
    it 'reloads the configuration' do
      described_class.load
      expect(described_class).to receive(:load).and_call_original
      described_class.reload
    end
  end

  describe 'app settings' do
    describe '.log_level' do
      it 'returns the configured log level' do
        expect(described_class.log_level).to eq('INFO')
      end
    end

    describe '.database_path' do
      it 'returns the configured database path' do
        expect(described_class.database_path).to eq('db/scopes.db')
      end
    end
  end

  describe 'http settings' do
    describe '.user_agent' do
      it 'returns the configured user agent' do
        expect(described_class.user_agent).to include('ScopesExtractor/2.0')
        expect(described_class.user_agent).to include('Ruby')
        expect(described_class.user_agent).to include('github.com')
      end
    end

    describe '.proxy' do
      it 'returns the configured proxy or nil' do
        proxy = described_class.proxy
        expect(proxy.nil? || proxy.is_a?(String)).to be true
      end
    end

    describe '.timeout' do
      it 'returns the configured timeout' do
        expect(described_class.timeout).to eq(30)
      end
    end
  end

  describe 'api settings' do
    describe '.api_port' do
      it 'returns the configured API port' do
        expect(described_class.api_port).to eq(4567)
      end
    end

    describe '.api_bind' do
      it 'returns the configured bind address' do
        expect(described_class.api_bind).to eq('0.0.0.0')
      end
    end
  end

  describe 'platform settings' do
    describe '.platforms' do
      it 'returns all platform configurations' do
        platforms = described_class.platforms
        expect(platforms).to have_key(:yeswehack)
        expect(platforms).to have_key(:hackerone)
        expect(platforms).to have_key(:intigriti)
        expect(platforms).to have_key(:bugcrowd)
      end
    end

    describe '.platform_enabled?' do
      it 'returns boolean for platform status' do
        result = described_class.platform_enabled?('yeswehack')
        expect(result).to be(true).or be(false)
      end
    end

    describe '.skip_vdp?' do
      it 'returns true for platforms configured to skip VDPs' do
        expect(described_class.skip_vdp?('yeswehack')).to be true
      end

      it 'returns false for platforms configured to include VDPs' do
        expect(described_class.skip_vdp?('hackerone')).to be false
      end
    end
  end

  describe 'sync settings' do
    describe '.sync' do
      it 'returns sync configuration' do
        sync = described_class.sync
        expect(sync[:auto]).to be true
        expect(sync[:delay]).to eq(10_800)
      end
    end
  end

  describe '.history_retention_days' do
    it 'returns the configured retention days' do
      expect(described_class.history_retention_days).to eq(30)
    end
  end

  describe 'discord settings' do
    describe '.discord_enabled?' do
      it 'returns the configured value' do
        result = described_class.discord_enabled?
        expect(result).to be(true).or be(false)
      end
    end

    describe '.discord_events' do
      it 'returns the configured events' do
        events = described_class.discord_events
        expect(events).to include('new_program')
        expect(events).to include('new_scope')
        expect(events).to include('removed_scope')
      end
    end

    describe '.discord_new_scope_types' do
      it 'returns the configured scope types for filtering' do
        types = described_class.discord_new_scope_types
        expect(types).to eq(['web'])
      end
    end
  end

  describe 'platform exclusions' do
    describe '.excluded?' do
      it 'returns false when program is not in exclusion list' do
        expect(described_class.excluded?('yeswehack', 'some-program')).to be false
      end

      it 'returns false for platforms with empty exclusion lists' do
        expect(described_class.excluded?('hackerone', 'any-program')).to be false
      end

      it 'works with string platform names' do
        allow(described_class).to receive(:platform_exclusions).and_return({
                                                                             yeswehack: %w[excluded-program-1 excluded-program-2],
                                                                             intigriti: ['test-program']
                                                                           })

        expect(described_class.excluded?('yeswehack', 'excluded-program-1')).to be true
        expect(described_class.excluded?('yeswehack', 'other-program')).to be false
        expect(described_class.excluded?('intigriti', 'test-program')).to be true
      end

      it 'works with symbol platform names' do
        allow(described_class).to receive(:platform_exclusions).and_return({
                                                                             yeswehack: ['excluded-program'],
                                                                             intigriti: []
                                                                           })

        expect(described_class.excluded?(:yeswehack, 'excluded-program')).to be true
        expect(described_class.excluded?(:intigriti, 'any-program')).to be false
      end
    end
  end
end
