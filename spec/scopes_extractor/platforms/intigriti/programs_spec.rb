# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Intigriti::Programs do
  describe '.sync' do
    let(:config) { { headers: { 'Authorization' => 'Bearer token' } } }
    let(:response) do
      double('HTTPResponse', status: 200,
                             body: '[{"name": "Test Program", "maxBounty": {"value": 1000}, "status": 1, "handle": "test-program", "companyHandle": "test-company"}]')
    end
    let(:results) { {} }

    before do
      allow(ScopesExtractor::HttpClient).to receive(:get).with(ScopesExtractor::Intigriti::Programs::PROGRAMS_ENDPOINT,
                                                               { headers: config[:headers] }).and_return(response)
      allow(ScopesExtractor::Intigriti::Scopes).to receive(:sync).and_return({})
    end

    it 'fetches and parses programs' do
      described_class.sync(results, config)
      expect(results).not_to be_empty
      expect(results['Test Program']).to include(:slug, :enabled, :private)
    end
  end

  describe '.parse_programs' do
    let(:programs) do
      [{ 'name' => 'Test Program', 'maxBounty' => { 'value' => 1000 }, 'status' => 1, 'handle' => 'test-program',
         'companyHandle' => 'test-company' }]
    end
    let(:config) { { headers: {} } }
    let(:results) { {} }
    let(:scoped_program_response) do
      double('HTTPResponse', status: 200, body: '{}')
    end
    before do
      stub_request(:get, 'https://app.intigriti.com/api/core/researcher/programs/test-company/test-program')
        .to_return(status: 200, body: scoped_program_response.body)

      allow(ScopesExtractor::Intigriti::Scopes).to receive(:sync).and_return({})
    end

    it 'parses program details and scopes' do
      described_class.parse_programs(programs, config, results)
      expect(results).not_to be_empty
      expect(results['Test Program']).to include(:slug, :enabled, :private)
    end
  end

  describe '.program_info' do
    let(:program) { { 'handle' => 'test-program', 'confidentialityLevel' => 4 } }

    it 'returns program info' do
      info = described_class.program_info(program)
      expect(info).to include(:slug, :enabled, :private)
    end
  end
end
