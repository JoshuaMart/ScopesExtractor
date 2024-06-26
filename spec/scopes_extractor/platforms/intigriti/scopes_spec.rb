# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Intigriti::Scopes do
  describe '.sync' do
    let(:program) { { id: 'test-program' } }
    let(:headers) { { 'Authorization' => 'Bearer token' } }
    let(:response) do
      double('HTTPResponse', status: 200,
                             body: '{"domains": {"content": [{"type": {"id": 1}, "tier": {"value": "In Scope"}, "endpoint": "http://example.com"}]}}')
    end

    before do
      allow(ScopesExtractor::HttpClient).to receive(:get).and_return(response)
      allow(ScopesExtractor::Parser).to receive(:json_parse).and_return(JSON.parse(response.body))
    end

    it 'fetches program scopes and returns parsed scopes' do
      scopes = described_class.sync(program, headers)
      expect(scopes).to include('in', 'out')
      expect(scopes['in']).to include(:url)
      expect(scopes['in'][:url]).to include('http://example.com')
    end
  end

  describe '.parse_scopes' do
    it 'categorizes and returns parsed scopes' do
      scopes = [{ 'type' => { 'id' => 1 }, 'tier' => { 'value' => 'In Scope' }, 'endpoint' => 'http://example.com' }]
      categorized_scopes = described_class.parse_scopes(scopes)
      expect(categorized_scopes).to have_key('in')
      expect(categorized_scopes['in']).to have_key(:url)
      expect(categorized_scopes['in'][:url]).to include('http://example.com')
    end
  end

  describe '.find_category' do
    it 'finds and returns the correct category for a given scope' do
      scope = { 'type' => { 'id' => 1 } }
      category = described_class.find_category(scope)
      expect(category).to eq(:url)
    end
  end

  describe '.normalize' do
    it 'normalizes and returns sanitized endpoints' do
      normalized = described_class.normalize('http://example.com/*')
      expect(normalized).to eq('http://example.com')
    end

    it 'normalizes and returns nil for improper endpoints' do
      normalized = described_class.normalize('Lorem Ipsum')
      expect(normalized).to be_nil
    end
  end

  describe '.sanitize_endpoint' do
    it 'sanitizes and returns endpoints' do
      sanitized = described_class.sanitize_endpoint('http://example.com/*')
      expect(sanitized).to eq('http://example.com')
    end
  end
end
