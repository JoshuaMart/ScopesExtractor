# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::YesWeHack::Programs do
  let(:config) { { headers: { 'Authorization' => 'Bearer token' } } }
  let(:page_id) { 1 }
  let(:results) { {} }

  describe '.sync' do
    let(:page_infos) { { programs: %w[program1 program2], nb_pages: 1 } }

    before do
      allow(described_class).to receive(:get_page_infos).with(page_id, config).and_return(page_infos)
      allow(described_class).to receive(:parse_programs)
    end

    it 'calls parse_programs with correct arguments' do
      described_class.sync(results, config, page_id)
      expect(described_class).to have_received(:parse_programs).with(page_infos[:programs], results, config)
    end

    context 'when page_infos is nil' do
      let(:page_infos) { nil }

      it 'returns nil' do
        expect(described_class.sync(results, config, page_id)).to be_nil
      end
    end
  end

  describe '.get_page_infos' do
    let(:response) do
      instance_double('Response', code: 200, body: '{"pagination": {"nb_pages": 2}, "items": ["item1", "item2"]}')
    end

    before do
      allow(ScopesExtractor::HttpClient).to receive(:get)
        .with("https://api.yeswehack.com/programs?page=#{page_id}", { headers: config[:headers] })
        .and_return(response)

      allow(ScopesExtractor::Parser).to receive(:json_parse).with(response.body)
                                                            .and_return(JSON.parse(response.body))
    end

    context 'when response is successful' do
      it 'returns the correct data structure' do
        expect(described_class.get_page_infos(page_id, config)).to eq({ nb_pages: 2, programs: %w[item1 item2] })
      end
    end

    context 'when response is not successful' do
      let(:response) { instance_double('Response', code: 404, body: '{}') }

      it 'returns nil' do
        expect(described_class.get_page_infos(page_id, config)).to be_nil
      end
    end
  end

  describe '.parse_programs' do
    let(:program) do
      { 'title' => 'Test Program', 'slug' => 'test-program', 'public' => true, 'disabled' => false, 'vdp' => false }
    end
    let(:programs) { [program] }

    before do
      allow(ScopesExtractor::YesWeHack::Scopes).to receive(:sync)
    end

    it 'parses programs and updates results' do
      described_class.parse_programs(programs, results, config)
      expect(results['Test Program']).to eq({ slug: 'test-program', private: false, 'scopes' => nil })
    end

    context 'when a program is disabled or vdp' do
      let(:disabled_program) { { 'disabled' => true, 'vdp' => true } }

      it 'skips disabled or vdp programs' do
        described_class.parse_programs([disabled_program], results, config)
        expect(results).to be_empty
      end
    end
  end
end
