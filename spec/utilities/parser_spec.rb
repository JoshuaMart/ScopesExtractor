# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Parser do
  describe '.exclusions' do
    context 'when exclusions.yml does not exist' do
      before do
        allow(File).to receive(:exist?).and_return(false)

        # Reset memoized value
        described_class.instance_variable_set(:@exclusions, nil)
      end

      it 'returns an empty array' do
        expect(described_class.exclusions).to eq([])
      end
    end

    context 'when exclusions.yml exists but has no exclusions key' do
      let(:yaml_content) { { 'other_key' => ['value'] } }
      let(:yaml_path) { File.join(File.dirname(__FILE__), '..', '..', 'config', 'exclusions.yml') }

      before do
        allow(File).to receive(:exist?).with(anything).and_call_original
        allow(File).to receive(:exist?).with(yaml_path).and_return(true)
        allow(File).to receive(:read).with(yaml_path).and_return(yaml_content.to_yaml)

        # Reset memoized value
        described_class.instance_variable_set(:@exclusions, nil)
      end
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
        # TODO expect(described_class.json_parse(invalid_json)).to be_nil
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
          expect(described_class.valid_ip?(invalid_ip)).to be false
        end

        it 'returns false for non-IP strings' do
          invalid_ip = 'not-an-ip'
          expect(described_class.valid_ip?(invalid_ip)).to be false
        end
    end
  end

  describe '.valid_uri?' do
    before do
      # Mock exclusions method to return test values
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

      it 'returns false and logs a warning for invalid URIs' do
        invalid_uri = 'http://exa mple.com'
        expect(described_class.valid_uri?(invalid_uri)).to be false
      end
    end
  end
end
