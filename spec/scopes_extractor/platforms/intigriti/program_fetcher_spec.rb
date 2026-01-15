# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Platforms::Intigriti::ProgramFetcher do
  let(:token) { 'test_bearer_token' }
  let(:fetcher) { described_class.new(token) }

  describe '#initialize' do
    it 'stores the token' do
      expect(fetcher.instance_variable_get(:@token)).to eq(token)
    end
  end

  describe '#fetch_all' do
    context 'with single page of programs' do
      let(:response_body) do
        {
          'records' => [
            { 'id' => '1', 'handle' => 'program1' },
            { 'id' => '2', 'handle' => 'program2' }
          ],
          'maxCount' => 2
        }.to_json
      end
      let(:response) { double('Response', success?: true, code: 200, body: response_body) }

      before do
        allow(ScopesExtractor::HTTP).to receive(:get).and_return(response)
      end

      it 'fetches all programs' do
        programs = fetcher.fetch_all
        expect(programs.size).to eq(2)
        expect(programs.first['handle']).to eq('program1')
      end

      it 'logs the fetch operation' do
        expect(ScopesExtractor.logger).to receive(:debug).with('[Intigriti] Fetching programs with offset 0')
        expect(ScopesExtractor.logger).to receive(:info).with('[Intigriti] Fetched 2 programs')
        fetcher.fetch_all
      end
    end

    context 'with multiple pages of programs' do
      let(:page1_response) do
        {
          'records' => [{ 'id' => '1', 'handle' => 'program1' }],
          'maxCount' => 2
        }.to_json
      end
      let(:page2_response) do
        {
          'records' => [{ 'id' => '2', 'handle' => 'program2' }],
          'maxCount' => 2
        }.to_json
      end
      let(:empty_response) do
        {
          'records' => [],
          'maxCount' => 2
        }.to_json
      end

      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('offset=0'), any_args)
          .and_return(double('Response', success?: true, code: 200, body: page1_response))
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('offset=100'), any_args)
          .and_return(double('Response', success?: true, code: 200, body: page2_response))
      end

      it 'fetches all pages' do
        programs = fetcher.fetch_all
        expect(programs.size).to eq(2)
      end

      it 'logs each fetch' do
        expect(ScopesExtractor.logger).to receive(:debug).with('[Intigriti] Fetching programs with offset 0')
        expect(ScopesExtractor.logger).to receive(:debug).with('[Intigriti] Fetching programs with offset 100')
        expect(ScopesExtractor.logger).to receive(:info).with('[Intigriti] Fetched 2 programs')
        fetcher.fetch_all
      end
    end

    context 'when API returns empty data' do
      let(:response) { double('Response', success?: true, code: 200, body: { 'records' => [], 'maxCount' => 0 }.to_json) }

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
        expect { fetcher.fetch_all }.to raise_error(StandardError, /Failed to fetch programs/)
      end
    end

    context 'when maxCount is reached' do
      let(:page1_response) do
        {
          'records' => [{ 'id' => '1' }, { 'id' => '2' }],
          'maxCount' => 2
        }.to_json
      end

      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .and_return(double('Response', success?: true, code: 200, body: page1_response))
      end

      it 'stops fetching when total is reached' do
        expect(ScopesExtractor::HTTP).to receive(:get).once
        fetcher.fetch_all
      end
    end
  end

  describe '#fetch_details' do
    let(:program_id) { '123abc' }

    context 'when program details are accessible' do
      let(:response_body) do
        {
          'id' => program_id,
          'handle' => 'test-program',
          'domains' => {
            'content' => [
              { 'endpoint' => 'example.com' }
            ]
          }
        }.to_json
      end
      let(:response) { double('Response', success?: true, code: 200, body: response_body) }

      before do
        allow(ScopesExtractor::HTTP).to receive(:get).and_return(response)
      end

      it 'fetches program details' do
        details = fetcher.fetch_details(program_id)
        expect(details).to be_a(Hash)
        expect(details['handle']).to eq('test-program')
      end
    end

    context 'when program is not accessible (403)' do
      let(:response) { double('Response', success?: false, code: 403) }

      before do
        allow(ScopesExtractor::HTTP).to receive(:get).and_return(response)
      end

      it 'returns nil' do
        details = fetcher.fetch_details(program_id)
        expect(details).to be_nil
      end

      it 'logs debug message for 403' do
        expect(ScopesExtractor.logger).to receive(:debug)
          .with("[Intigriti] Program #{program_id} not accessible (403 - not accepted)")
        fetcher.fetch_details(program_id)
      end
    end

    context 'when other error occurs' do
      let(:response) { double('Response', success?: false, code: 500) }

      before do
        allow(ScopesExtractor::HTTP).to receive(:get).and_return(response)
      end

      it 'returns nil' do
        details = fetcher.fetch_details(program_id)
        expect(details).to be_nil
      end

      it 'logs warning message for other errors' do
        expect(ScopesExtractor.logger).to receive(:warn)
          .with("[Intigriti] Failed to fetch program #{program_id}: 500")
        fetcher.fetch_details(program_id)
      end
    end
  end
end
