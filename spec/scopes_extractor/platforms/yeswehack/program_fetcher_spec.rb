# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe ScopesExtractor::Platforms::YesWeHack::ProgramFetcher do
  let(:token) { 'test_token_123' }
  let(:fetcher) { described_class.new(token) }

  describe '#fetch_all' do
    context 'with single page of programs' do
      before do
        stub_request(:get, 'https://api.yeswehack.com/programs?page=1')
          .with(headers: { 'Authorization' => 'Bearer test_token_123' })
          .to_return(
            status: 200,
            body: {
              items: [
                { slug: 'program-1', title: 'Program 1' },
                { slug: 'program-2', title: 'Program 2' }
              ],
              pagination: { nb_pages: 1 }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'fetches all programs' do
        programs = fetcher.fetch_all
        expect(programs.size).to eq(2)
        expect(programs.first['slug']).to eq('program-1')
      end

      it 'logs the number of programs fetched' do
        expect(ScopesExtractor.logger).to receive(:info).with(/Fetched 2 programs/)
        fetcher.fetch_all
      end
    end

    context 'with multiple pages of programs' do
      before do
        # Page 1
        stub_request(:get, 'https://api.yeswehack.com/programs?page=1')
          .with(headers: { 'Authorization' => 'Bearer test_token_123' })
          .to_return(
            status: 200,
            body: {
              items: [{ slug: 'program-1' }],
              pagination: { nb_pages: 2 }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Page 2
        stub_request(:get, 'https://api.yeswehack.com/programs?page=2')
          .with(headers: { 'Authorization' => 'Bearer test_token_123' })
          .to_return(
            status: 200,
            body: {
              items: [{ slug: 'program-2' }],
              pagination: { nb_pages: 2 }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'fetches all pages' do
        programs = fetcher.fetch_all
        expect(programs.size).to eq(2)
        expect(programs.map { |p| p['slug'] }).to eq(%w[program-1 program-2])
      end

      it 'logs each page fetch' do
        expect(ScopesExtractor.logger).to receive(:debug).with(/Fetching programs page 1/)
        expect(ScopesExtractor.logger).to receive(:debug).with(/Fetching programs page 2/)
        allow(ScopesExtractor.logger).to receive(:debug) # Allow HTTP logs
        allow(ScopesExtractor.logger).to receive(:info)
        fetcher.fetch_all
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:get, 'https://api.yeswehack.com/programs?page=1')
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises an exception' do
        expect do
          fetcher.fetch_all
        end.to raise_error(StandardError, /Failed to fetch programs: HTTP 500/)
      end
    end

    context 'when API returns empty items' do
      before do
        stub_request(:get, 'https://api.yeswehack.com/programs?page=1')
          .to_return(
            status: 200,
            body: { items: [], pagination: { nb_pages: 1 } }.to_json
          )
      end

      it 'returns empty array' do
        programs = fetcher.fetch_all
        expect(programs).to eq([])
      end
    end
  end

  describe '#fetch_details' do
    let(:slug) { 'test-program' }

    context 'when program exists' do
      let(:program_details) do
        {
          slug: 'test-program',
          title: 'Test Program',
          bounty: true,
          scopes: [{ scope: '*.example.com', scope_type: 'web-application' }]
        }
      end

      before do
        stub_request(:get, "https://api.yeswehack.com/programs/#{slug}")
          .with(headers: { 'Authorization' => 'Bearer test_token_123' })
          .to_return(
            status: 200,
            body: program_details.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns program details' do
        details = fetcher.fetch_details(slug)
        expect(details).not_to be_nil
        expect(details['slug']).to eq('test-program')
        expect(details['title']).to eq('Test Program')
      end
    end

    context 'when program does not exist' do
      before do
        stub_request(:get, "https://api.yeswehack.com/programs/#{slug}")
          .to_return(status: 404, body: 'Not Found')
      end

      it 'returns nil' do
        details = fetcher.fetch_details(slug)
        expect(details).to be_nil
      end
    end

    context 'when API returns server error' do
      before do
        stub_request(:get, "https://api.yeswehack.com/programs/#{slug}")
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'returns nil' do
        details = fetcher.fetch_details(slug)
        expect(details).to be_nil
      end
    end
  end
end
