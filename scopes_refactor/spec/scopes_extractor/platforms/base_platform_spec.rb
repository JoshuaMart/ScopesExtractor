# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Platforms::BasePlatform do
  # Create a concrete test class to test the abstract base
  let(:test_platform_class) do
    Class.new(described_class) do
      def name
        'TestPlatform'
      end

      def fetch_programs
        []
      end
    end
  end

  let(:platform) { test_platform_class.new(test_config: 'value') }

  describe '#initialize' do
    it 'accepts a config hash' do
      expect(platform.config).to eq(test_config: 'value')
    end

    it 'defaults to empty hash when no config provided' do
      platform = test_platform_class.new
      expect(platform.config).to eq({})
    end
  end

  describe '#name' do
    it 'raises NotImplementedError when not overridden' do
      base_instance = described_class.new
      expect { base_instance.name }.to raise_error(NotImplementedError, /must implement #name/)
    end

    it 'returns the platform name when implemented' do
      expect(platform.name).to eq('TestPlatform')
    end
  end

  describe '#fetch_programs' do
    it 'raises NotImplementedError when not overridden' do
      base_instance = described_class.new
      expect { base_instance.fetch_programs }.to raise_error(NotImplementedError, /must implement #fetch_programs/)
    end

    it 'returns an array when implemented' do
      expect(platform.fetch_programs).to eq([])
    end
  end

  describe '#valid_access?' do
    it 'returns true by default' do
      expect(platform.valid_access?).to be true
    end

    it 'can be overridden by subclasses' do
      custom_platform_class = Class.new(described_class) do
        def name
          'CustomPlatform'
        end

        def fetch_programs
          []
        end

        def valid_access?
          false
        end
      end

      custom_platform = custom_platform_class.new
      expect(custom_platform.valid_access?).to be false
    end
  end
end
