# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Intigriti::Scopes do
  describe '.sync' do
    let(:program) { { company: 'test-company', handle: 'test-program' } }
    let(:headers) { { 'Authorization' => 'Bearer token' } }
    let(:response) { double('HTTPResponse', status: 200, body: 'response body') }

    before do
      allow(ScopesExtractor::HttpClient).to receive(:get).and_return(response)
      allow(ScopesExtractor::Parser).to receive(:json_parse).and_return({ 'domains' => [{ 'content' => [] }],
                                                                          'outOfScopes' => [{ 'content' => { 'content' => [] } }] })
    end

    it 'fetches program scopes and returns parsed scopes' do
      scopes = described_class.sync(program, headers)
      expect(scopes).to include('in', 'out')
    end
  end

  describe '.prepare_scope_url' do
    let(:program) { { company: 'test-company', handle: 'test-program' } }

    it 'prepares and returns the correct scope URL' do
      url = described_class.prepare_scope_url(program)
      expect(url).to include('test-company', 'test-program')
    end
  end

  describe '.parse_scopes' do
    let(:scopes) { [{ 'type' => 1, 'endpoint' => 'http://example.com' }] }
    let(:in_scope) { true }

    it 'categorizes and returns parsed scopes' do
      categorized_scopes = described_class.parse_scopes(scopes, in_scope)
      expect(categorized_scopes).to have_key(:url)
    end
  end

  describe '.find_category' do
    let(:scope) { { 'type' => 1 } }
    let(:in_scope) { true }

    it 'finds and returns the correct category for a given scope' do
      category = described_class.find_category(scope, in_scope)
      expect(category).to eq(:url)
    end
  end

  describe '.normalize' do
    it 'normalizes and returns sanitized endpoints' do
      normalized = described_class.normalize('http://example.com/*')
      expect(normalized).to eq('http://example.com')
    end
  end

  describe '.sanitize_endpoint' do
    it 'sanitizes and returns endpoints' do
      sanitized = described_class.sanitize_endpoint('http://example.com/*')
      expect(sanitized).to eq('http://example.com')
    end
  end
end
