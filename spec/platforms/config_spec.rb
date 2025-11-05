# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Config do
  describe '.load' do
    context 'when environment variables are not set' do
      before do
        # Clear relevant environment variables
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('API_MODE', 'false').and_return('false')
        allow(ENV).to receive(:fetch).with('AUTO_SYNC', 'false').and_return('false')
        allow(ENV).to receive(:fetch).with('YWH_SYNC', 'false').and_return('false')
        allow(ENV).to receive(:fetch).with('INTIGRITI_SYNC', 'false').and_return('false')
        allow(ENV).to receive(:fetch).with('H1_SYNC', 'false').and_return('false')
        allow(ENV).to receive(:fetch).with('BC_SYNC', 'false').and_return('false')
        allow(ENV).to receive(:fetch).with('IMMUNEFI_SYNC', 'false').and_return('false')
      end

      it 'returns string values for boolean configuration options' do
        config = described_class.load

        # API configuration
        expect(config[:api][:enabled]).to eq('false')
        expect(config[:api][:enabled]).to be_a(String)

        # Sync configuration
        expect(config[:sync][:auto]).to eq('false')
        expect(config[:sync][:auto]).to be_a(String)

        # Platform configurations
        expect(config[:yeswehack][:enabled]).to eq('false')
        expect(config[:yeswehack][:enabled]).to be_a(String)

        expect(config[:intigriti][:enabled]).to eq('false')
        expect(config[:intigriti][:enabled]).to be_a(String)

        expect(config[:hackerone][:enabled]).to eq('false')
        expect(config[:hackerone][:enabled]).to be_a(String)

        expect(config[:bugcrowd][:enabled]).to eq('false')
        expect(config[:bugcrowd][:enabled]).to be_a(String)

        expect(config[:immunefi][:enabled]).to eq('false')
        expect(config[:immunefi][:enabled]).to be_a(String)
      end

      it 'allows .downcase to be called on configuration values without error' do
        config = described_class.load

        expect { config[:api][:enabled].downcase }.not_to raise_error
        expect { config[:sync][:auto].downcase }.not_to raise_error
        expect { config[:yeswehack][:enabled].downcase }.not_to raise_error
        expect { config[:intigriti][:enabled].downcase }.not_to raise_error
        expect { config[:hackerone][:enabled].downcase }.not_to raise_error
        expect { config[:bugcrowd][:enabled].downcase }.not_to raise_error
        expect { config[:immunefi][:enabled].downcase }.not_to raise_error
      end
    end

    context 'when environment variables are set as strings' do
      before do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('API_MODE', 'false').and_return('true')
        allow(ENV).to receive(:fetch).with('AUTO_SYNC', 'false').and_return('true')
        allow(ENV).to receive(:fetch).with('YWH_SYNC', 'false').and_return('true')
      end

      it 'returns string values from environment' do
        config = described_class.load

        expect(config[:api][:enabled]).to eq('true')
        expect(config[:api][:enabled]).to be_a(String)

        expect(config[:sync][:auto]).to eq('true')
        expect(config[:sync][:auto]).to be_a(String)

        expect(config[:yeswehack][:enabled]).to eq('true')
        expect(config[:yeswehack][:enabled]).to be_a(String)
      end

      it 'allows .downcase to be called on configuration values without error' do
        config = described_class.load

        expect { config[:api][:enabled].downcase }.not_to raise_error
        expect { config[:sync][:auto].downcase }.not_to raise_error
        expect { config[:yeswehack][:enabled].downcase }.not_to raise_error

        expect(config[:api][:enabled].downcase).to eq('true')
        expect(config[:sync][:auto].downcase).to eq('true')
      end
    end

    context 'type consistency between defaults and environment variables' do
      it 'maintains string type consistency for api_mode comparison' do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('API_MODE', 'false').and_return('false')

        config = described_class.load

        # This should work without NoMethodError
        result = config.dig(:api, :enabled)&.downcase == 'true'
        expect(result).to be false
      end

      it 'maintains string type consistency for auto_sync comparison' do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('AUTO_SYNC', 'false').and_return('false')

        config = described_class.load

        # This should work without NoMethodError
        result = config.dig(:sync, :auto)&.downcase == 'true'
        expect(result).to be false
      end

      it 'correctly evaluates true values' do
        allow(ENV).to receive(:fetch).and_call_original
        allow(ENV).to receive(:fetch).with('API_MODE', 'false').and_return('true')
        allow(ENV).to receive(:fetch).with('AUTO_SYNC', 'false').and_return('true')

        config = described_class.load

        expect(config.dig(:api, :enabled)&.downcase == 'true').to be true
        expect(config.dig(:sync, :auto)&.downcase == 'true').to be true
      end
    end
  end
end
