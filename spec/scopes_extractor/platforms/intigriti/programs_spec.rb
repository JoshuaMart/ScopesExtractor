# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Intigriti::Programs do
  describe '.sync' do
    let(:config) { { headers: { 'Authorization' => 'Bearer token' } } }
    let(:response) do
      double('HTTPResponse', status: 200,
                             body: '{"records":[{"id": "test-program", "name": "Test Program", "maxBounty": {"value": 1000}, "status": {"value": "Active"}, "handle": "test-program", "confidentialityLevel": {"id": 3}}]}')
    end
    let(:results) { { 'Intigriti' => {} } }

    before do
      allow(ScopesExtractor::HttpClient).to receive(:get).with(ScopesExtractor::Intigriti::Programs::PROGRAMS_ENDPOINT,
                                                               { headers: config[:headers] }).and_return(response)
      allow(ScopesExtractor::Intigriti::Scopes).to receive(:sync).and_return({})
    end

    it 'fetches and parses programs' do
      described_class.sync(results, config)
      expect(results).not_to be_empty
      expect(results['Intigriti']['Test Program']).to include(:slug, :enabled, :private)
      expect(results['Intigriti']['Test Program'][:scopes]).to eq({})
    end
  end

  describe '.parse_programs' do
    let(:programs) do
      [{ 'id' => 'test-program', 'name' => 'Test Program', 'maxBounty' => { 'value' => 1000 }, 'status' => { 'value' => 'Active' },
         'handle' => 'test-program', 'confidentialityLevel' => { 'id' => 3 } }]
    end
    let(:config) { { headers: { 'Authorization' => 'Bearer token' } } }
    let(:results) { { 'Intigriti' => {} } }

    before do
      allow(ScopesExtractor::Intigriti::Scopes).to receive(:sync).with({ id: 'test-program' },
                                                                       config[:headers]).and_return({})
    end

    it 'parses program details and scopes' do
      described_class.parse_programs(programs, config, results)
      expect(results).not_to be_empty
      expect(results['Intigriti']['Test Program']).to include(:slug, :enabled, :private)
      expect(results['Intigriti']['Test Program'][:scopes]).to eq({})
    end
  end

  describe '.program_info' do
    let(:program) { { 'handle' => 'test-program', 'confidentialityLevel' => { 'id' => 3 } } }

    it 'returns program info indicating that the program is public' do
      info = described_class.program_info(program)
      expect(info[:slug]).to eq('test-program')
      expect(info[:enabled]).to be(true)
      expect(info[:private]).to be(true)
    end
  end
end
