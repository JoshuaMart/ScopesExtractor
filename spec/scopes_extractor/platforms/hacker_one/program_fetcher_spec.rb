# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Platforms::HackerOne::ProgramFetcher do
  let(:auth_header) { Base64.strict_encode64('test_user:test_token') }
  let(:fetcher) { described_class.new(auth_header) }

  describe '#fetch_all' do
    context 'with single page of programs' do
      let(:response_body) do
        {
          'data' => [
            { 'id' => '1', 'attributes' => { 'handle' => 'program1' } },
            { 'id' => '2', 'attributes' => { 'handle' => 'program2' } }
          ],
          'links' => {}
        }.to_json
      end
      let(:response) { double('Response', success?: true, code: 200, body: response_body) }

      before do
        allow(ScopesExtractor::HTTP).to receive(:get).and_return(response)
      end

      it 'fetches all programs' do
        programs = fetcher.fetch_all
        expect(programs.size).to eq(2)
        expect(programs.first['attributes']['handle']).to eq('program1')
      end

      it 'logs the fetch operation' do
        expect(ScopesExtractor.logger).to receive(:debug).with('[HackerOne] Fetching programs page 1')
        expect(ScopesExtractor.logger).to receive(:debug).with('[HackerOne] Fetched 2 programs from page 1')
        expect(ScopesExtractor.logger).to receive(:info).with('[HackerOne] Fetched total of 2 program(s)')
        fetcher.fetch_all
      end
    end

    context 'with multiple pages of programs' do
      let(:page1_response) do
        {
          'data' => [
            { 'id' => '1', 'attributes' => { 'handle' => 'program1' } }
          ],
          'links' => { 'next' => 'http://api.hackerone.com/v1/hackers/programs?page=2' }
        }.to_json
      end
      let(:page2_response) do
        {
          'data' => [
            { 'id' => '2', 'attributes' => { 'handle' => 'program2' } }
          ],
          'links' => {}
        }.to_json
      end
      let(:response1) { double('Response', success?: true, code: 200, body: page1_response) }
      let(:response2) { double('Response', success?: true, code: 200, body: page2_response) }

      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .and_return(response1, response2)
      end

      it 'fetches all pages' do
        programs = fetcher.fetch_all
        expect(programs.size).to eq(2)
      end

      it 'logs each page fetch' do
        expect(ScopesExtractor.logger).to receive(:debug).with('[HackerOne] Fetching programs page 1')
        expect(ScopesExtractor.logger).to receive(:debug).with('[HackerOne] Fetched 1 programs from page 1')
        expect(ScopesExtractor.logger).to receive(:debug).with('[HackerOne] Fetching programs page 2')
        expect(ScopesExtractor.logger).to receive(:debug).with('[HackerOne] Fetched 1 programs from page 2')
        expect(ScopesExtractor.logger).to receive(:info).with('[HackerOne] Fetched total of 2 program(s)')
        fetcher.fetch_all
      end
    end

    context 'when API returns empty data' do
      let(:response_body) do
        {
          'data' => [],
          'links' => {}
        }.to_json
      end
      let(:response) { double('Response', success?: true, code: 200, body: response_body) }

      before do
        allow(ScopesExtractor::HTTP).to receive(:get).and_return(response)
      end

      it 'returns empty array' do
        programs = fetcher.fetch_all
        expect(programs).to be_empty
      end
    end

    context 'when API returns error' do
      let(:response) { double('Response', success?: false, code: 401) }

      before do
        allow(ScopesExtractor::HTTP).to receive(:get).and_return(response)
      end

      it 'raises an exception' do
        expect { fetcher.fetch_all }.to raise_error(StandardError, /Failed to fetch programs page 1/)
      end
    end
  end

  describe '#fetch_scopes' do
    let(:handle) { 'test-program' }

    context 'with single page of scopes' do
      let(:response_body) do
        {
          'data' => [
            {
              'id' => '1',
              'attributes' => {
                'asset_identifier' => 'example.com',
                'asset_type' => 'URL'
              }
            },
            {
              'id' => '2',
              'attributes' => {
                'asset_identifier' => '*.example.com',
                'asset_type' => 'WILDCARD'
              }
            }
          ],
          'links' => {}
        }.to_json
      end
      let(:response) { double('Response', success?: true, code: 200, body: response_body) }

      before do
        allow(ScopesExtractor::HTTP).to receive(:get).and_return(response)
      end

      it 'fetches all scopes for the program' do
        scopes = fetcher.fetch_scopes(handle)
        expect(scopes.size).to eq(2)
        expect(scopes.first['attributes']['asset_identifier']).to eq('example.com')
      end
    end

    context 'with multiple pages of scopes' do
      let(:page1_response) do
        {
          'data' => [
            { 'id' => '1', 'attributes' => { 'asset_identifier' => 'example.com' } }
          ],
          'links' => { 'next' => 'http://api.hackerone.com/v1/hackers/programs/test/scopes?page=2' }
        }.to_json
      end
      let(:page2_response) do
        {
          'data' => [
            { 'id' => '2', 'attributes' => { 'asset_identifier' => 'api.example.com' } }
          ],
          'links' => {}
        }.to_json
      end
      let(:response1) { double('Response', success?: true, code: 200, body: page1_response) }
      let(:response2) { double('Response', success?: true, code: 200, body: page2_response) }

      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .and_return(response1, response2)
      end

      it 'fetches all pages of scopes' do
        scopes = fetcher.fetch_scopes(handle)
        expect(scopes.size).to eq(2)
      end
    end

    context 'when API returns empty scopes' do
      let(:response_body) do
        {
          'data' => [],
          'links' => {}
        }.to_json
      end
      let(:response) { double('Response', success?: true, code: 200, body: response_body) }

      before do
        allow(ScopesExtractor::HTTP).to receive(:get).and_return(response)
      end

      it 'returns empty array' do
        scopes = fetcher.fetch_scopes(handle)
        expect(scopes).to be_empty
      end
    end

    context 'when API returns error' do
      let(:response) { double('Response', success?: false, code: 404) }

      before do
        allow(ScopesExtractor::HTTP).to receive(:get).and_return(response)
      end

      it 'raises an exception' do
        expect { fetcher.fetch_scopes(handle) }.to raise_error(StandardError, /Failed to fetch scopes for #{handle}/)
      end
    end
  end
end
