# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::YesWeHack::Scopes do
  describe '.sync' do
    let(:program) { { slug: 'test-program' } }
    let(:config) { { headers: { 'Authorization' => 'Bearer token' } } }
    let(:response) { double('HTTPResponse', status: 200, body: '{"scopes": [], "out_of_scope": []}') }

    before do
      allow(ScopesExtractor::HttpClient).to receive(:get).and_return(response)
    end

    it 'calls the YesWeHack API with correct parameters' do
      described_class.sync(program, config)
      expect(ScopesExtractor::HttpClient).to have_received(:get).with(
        "https://api.yeswehack.com/programs/#{program[:slug]}", { headers: config[:headers] }
      )
    end

    it 'returns parsed scopes if response status is 200' do
      expect(described_class.sync(program, config)).to include('in', 'out')
    end

    context 'when the API response is not 200' do
      let(:response) { double('HTTPResponse', status: 404, body: '{}') }

      before do
        allow(ScopesExtractor::HttpClient).to receive(:get).and_return(response)
      end

      it 'returns an empty hash' do
        expect(described_class.sync(program, config)).to eq({})
      end
    end

    context 'when the parser returns nil' do
      let(:response) { double('HTTPResponse', status: 200, body: 'invalid json') }

      before do
        allow(ScopesExtractor::HttpClient).to receive(:get).and_return(response)
      end

      it 'returns nil' do
        expect(described_class.sync(program, config)).to be_nil
      end
    end
  end

  describe '.parse_scopes' do
    let(:data) { [{ 'scope_type' => 'web-application', 'scope' => 'example.com' }] }

    context 'when in_scope is true' do
      it 'categorizes scopes based on scope type' do
        result = described_class.parse_scopes(data, true)
        expect(result).to have_key(:url)
        expect(result[:url]).to include('example.com')
      end
    end

    context 'when in_scope is false' do
      let(:data) { [{ 'scope_type' => 'other', 'scope' => 'non-standard-scope' }] }

      it 'includes the scope even if the category is not found' do
        result = described_class.parse_scopes(data, false)
        expect(result).to have_key(:other)
        expect(result[:other]).to include('non-standard-scope')
      end
    end

    context 'when no category matches the scope type' do
      let(:data) { [{ 'scope_type' => 'unknown-category', 'scope' => 'example.com' }] }

      it 'does not include the scope if in_scope is true' do
        result = described_class.parse_scopes(data, true)
        expect(result).not_to have_key(:url)
      end
    end
  end

  describe '.add_scope_to_category' do
    let(:scopes) { {} }
    let(:category) { :url }
    let(:infos) { { 'scope' => 'example.com' } }

    it 'adds scope to the correct category' do
      scopes[category] ||= []
      described_class.add_scope_to_category(scopes, category, infos)
      expect(scopes[category]).to include('example.com')
    end
  end

  describe '.find_category' do
    let(:infos) { { 'scope_type' => 'web-application' } }

    it 'finds the correct category for a given scope type' do
      category = described_class.find_category(infos, true)
      expect(category).to eq(:url)
    end

    it 'returns nil for an unknown scope type' do
      unknown_infos = { 'scope_type' => 'unknown-type' }
      category = described_class.find_category(unknown_infos, true)
      expect(category).to be_nil
    end
  end

  describe '.normalize_urls' do
    context 'when given various URL formats' do
      it 'normalizes URLs with multiple subdomains' do
        expect(described_class.normalize_urls('(a|b|c).domain.tld'))
          .to eq(['a.domain.tld', 'b.domain.tld', 'c.domain.tld'])
      end

      it 'normalizes URLs with multiple TLDs' do
        expect(described_class.normalize_urls('*.domain.(a|b|c)'))
          .to eq(['*.domain.a', '*.domain.b', '*.domain.c'])
      end
    end
  end
end
