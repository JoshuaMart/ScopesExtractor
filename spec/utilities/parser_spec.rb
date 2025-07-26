# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Parser do
  describe '.parser_config' do
    before do
      # Reset memoized value
      described_class.instance_variable_set(:@parser_config, nil)
    end

    it 'loads parser configuration from Config' do
      expect(ScopesExtractor::Config).to receive(:load).and_return(
        parser: {
          notify_uri_errors: true,
          exclusions: ['test.com']
        }
      )

      config = described_class.parser_config
      expect(config[:notify_uri_errors]).to be true
      expect(config[:exclusions]).to eq(['test.com'])
    end

    it 'memoizes the configuration' do
      expect(ScopesExtractor::Config).to receive(:load).once.and_return(
        parser: { notify_uri_errors: false, exclusions: [] }
      )

      # Call twice, should only load once
      described_class.parser_config
      described_class.parser_config
    end
  end

  describe '.exclusions' do
    before do
      # Reset memoized value
      described_class.instance_variable_set(:@parser_config, nil)
    end

    it 'returns exclusions from parser config' do
      allow(described_class).to receive(:parser_config).and_return(
        { exclusions: ['excluded1.com', 'excluded2.com'] }
      )

      expect(described_class.exclusions).to eq(['excluded1.com', 'excluded2.com'])
    end

    it 'returns empty array when no exclusions configured' do
      allow(described_class).to receive(:parser_config).and_return(
        { exclusions: [] }
      )

      expect(described_class.exclusions).to eq([])
    end
  end

  describe '.json_parse' do
    context 'with valid JSON' do
      it 'parses JSON objects correctly' do
        json_string = '{"key": "value", "number": 42}'
        expected = { 'key' => 'value', 'number' => 42 }
        expect(described_class.json_parse(json_string)).to eq(expected)
      end

      it 'parses JSON arrays correctly' do
        json_string = '[1, 2, 3, "test"]'
        expected = [1, 2, 3, 'test']
        expect(described_class.json_parse(json_string)).to eq(expected)
      end
    end

    context 'with invalid JSON' do
      it 'returns nil and logs a warning' do
        invalid_json = '{"broken": "json'
        expect(ScopesExtractor::Discord).to receive(:log_warn).with("JSON parsing error : #{invalid_json}")
        expect(described_class.json_parse(invalid_json)).to be_nil
      end
    end
  end

  describe '.valid_ip?' do
    context 'with valid IP addresses' do
      it 'returns true for valid IPv4 addresses' do
        expect(described_class.valid_ip?('192.168.1.1')).to be true
        expect(described_class.valid_ip?('10.0.0.1')).to be true
        expect(described_class.valid_ip?('127.0.0.1')).to be true
      end

      it 'returns true for valid IPv6 addresses' do
        expect(described_class.valid_ip?('::1')).to be true
        expect(described_class.valid_ip?('2001:db8::1')).to be true
        expect(described_class.valid_ip?('fe80::1')).to be true
      end
    end

    context 'with invalid IP addresses' do
      it 'returns false and logs a warning' do
        invalid_ip = '256.256.256.256'
        expect(ScopesExtractor::Discord).to receive(:log_warn).with("Bad IPAddr for '#{invalid_ip}'")
        expect(described_class.valid_ip?(invalid_ip)).to be false
      end

      it 'returns false for non-IP strings' do
        invalid_ip = 'not-an-ip'
        expect(ScopesExtractor::Discord).to receive(:log_warn).with("Bad IPAddr for '#{invalid_ip}'")
        expect(described_class.valid_ip?(invalid_ip)).to be false
      end
    end
  end

  describe '.valid_uri?' do
    before do
      # Mock the parser_config and exclusions methods
      allow(described_class).to receive(:exclusions).and_return(['excluded.com'])
    end

    context 'with valid URIs' do
      it 'returns true for valid URIs with scheme' do
        expect(described_class.valid_uri?('https://example.com')).to be true
        expect(described_class.valid_uri?('http://sub.domain.org/path')).to be true
      end

      it 'returns true for valid hostnames without scheme' do
        expect(described_class.valid_uri?('example.com')).to be true
        expect(described_class.valid_uri?('sub.example.org')).to be true
      end
    end

    context 'with a wildcard' do
      it 'returns true for valid wildcard without scheme' do
        expect(described_class.valid_uri?('*.example.com')).to be true
      end
    end

    context 'with invalid URIs' do
      it 'returns false for excluded URIs' do
        expect(described_class.valid_uri?('excluded.com')).to be false
      end

      context 'when notifications are enabled' do
        before do
          allow(described_class).to receive(:parser_config).and_return(
            { notify_uri_errors: true }
          )
        end

        it 'returns false and logs a warning for invalid URIs' do
          invalid_uri = 'http://exa mple.com'
          expect(ScopesExtractor::Discord).to receive(:log_warn).with("Bad URI for '#{invalid_uri}'")
          expect(described_class.valid_uri?(invalid_uri)).to be false
        end
      end

      context 'when notifications are disabled' do
        before do
          allow(described_class).to receive(:parser_config).and_return(
            { notify_uri_errors: false }
          )
        end

        it 'returns false but does not log a warning for invalid URIs' do
          invalid_uri = 'http://exa mple.com'
          expect(ScopesExtractor::Discord).not_to receive(:log_warn)
          expect(described_class.valid_uri?(invalid_uri)).to be false
        end
      end
    end
  end
end
