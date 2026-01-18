# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Platforms::HackerOne::Platform do
  let(:config) { { username: 'test_user', api_token: 'test_token' } }
  let(:platform) { described_class.new(config) }

  describe '#initialize' do
    it 'accepts a config hash' do
      expect(platform).to be_a(described_class)
    end
  end

  describe '#name' do
    it 'returns HackerOne' do
      expect(platform.name).to eq('HackerOne')
    end
  end

  describe '#valid_access?' do
    context 'when credentials are missing' do
      let(:config) { {} }

      it 'returns false' do
        expect(platform.valid_access?).to be false
      end
    end

    context 'when credentials are provided' do
      context 'when API returns success' do
        let(:response) { double('Response', success?: true, code: 200) }

        before do
          allow(ScopesExtractor::HTTP).to receive(:get).and_return(response)
        end

        it 'returns true' do
          expect(platform.valid_access?).to be true
        end

        it 'logs debug message' do
          expect(ScopesExtractor.logger).to receive(:debug).with('[HackerOne] Access validation successful')
          platform.valid_access?
        end
      end

      context 'when API returns error' do
        let(:response) { double('Response', success?: false, code: 401) }

        before do
          allow(ScopesExtractor::HTTP).to receive(:get).and_return(response)
        end

        it 'returns false' do
          expect(platform.valid_access?).to be false
        end

        it 'logs error message' do
          expect(ScopesExtractor.logger).to receive(:error).with('[HackerOne] Access validation failed: 401')
          platform.valid_access?
        end
      end

      context 'when HTTP request raises an error' do
        it 'returns false' do
          allow(ScopesExtractor::HTTP).to receive(:get).and_raise(StandardError, 'Connection timeout')
          expect(platform.valid_access?).to be false
        end

        it 'logs error message' do
          allow(ScopesExtractor::HTTP).to receive(:get).and_raise(StandardError, 'Connection timeout')
          expect(ScopesExtractor.logger).to receive(:error).with('[HackerOne] Access validation error: Connection timeout')
          platform.valid_access?
        end
      end
    end
  end

  describe '#fetch_programs' do
    let(:fetcher) { instance_double(ScopesExtractor::Platforms::HackerOne::ProgramFetcher) }
    let(:raw_programs) do
      [
        {
          'attributes' => {
            'handle' => 'test-program',
            'name' => 'Test Program',
            'submission_state' => 'open',
            'offers_bounties' => true
          }
        }
      ]
    end
    let(:scopes_data) do
      [
        {
          'attributes' => {
            'asset_identifier' => 'example.com',
            'asset_type' => 'URL',
            'eligible_for_submission' => true,
            'eligible_for_bounty' => true
          }
        }
      ]
    end

    before do
      allow(ScopesExtractor::Platforms::HackerOne::ProgramFetcher).to receive(:new).and_return(fetcher)
      allow(fetcher).to receive(:fetch_all).and_return(raw_programs)
      allow(fetcher).to receive(:fetch_scopes).with('test-program').and_return(scopes_data)
    end

    it 'creates a program fetcher with auth header' do
      expect(ScopesExtractor::Platforms::HackerOne::ProgramFetcher).to receive(:new).with(kind_of(String))
      platform.fetch_programs
    end

    it 'fetches all programs' do
      expect(fetcher).to receive(:fetch_all)
      platform.fetch_programs
    end

    it 'fetches scopes for each program' do
      expect(fetcher).to receive(:fetch_scopes).with('test-program')
      platform.fetch_programs
    end

    it 'returns array of programs' do
      programs = platform.fetch_programs
      expect(programs).to be_an(Array)
      expect(programs.size).to eq(1)
      expect(programs.first).to be_a(ScopesExtractor::Models::Program)
      expect(programs.first.slug).to eq('test-program')
    end

    context 'when program is not open' do
      let(:raw_programs) do
        [
          {
            'attributes' => {
              'handle' => 'closed-program',
              'name' => 'Closed Program',
              'submission_state' => 'disabled',
              'offers_bounties' => true
            }
          }
        ]
      end

      it 'skips the program' do
        programs = platform.fetch_programs
        expect(programs).to be_empty
      end
    end

    context 'when program is VDP and skip_vdp is true' do
      let(:raw_programs) do
        [
          {
            'attributes' => {
              'handle' => 'vdp-program',
              'name' => 'VDP Program',
              'submission_state' => 'open',
              'offers_bounties' => false
            }
          }
        ]
      end

      before do
        allow(ScopesExtractor::Config).to receive(:skip_vdp?).with('hackerone').and_return(true)
      end

      it 'skips the program' do
        expect(ScopesExtractor.logger).to receive(:debug).with('[HackerOne] Skipping VDP program: vdp-program')
        programs = platform.fetch_programs
        expect(programs).to be_empty
      end
    end

    context 'when fetching scopes fails' do
      before do
        allow(fetcher).to receive(:fetch_scopes).and_raise(StandardError, 'API error')
      end

      it 'logs the error' do
        expect(ScopesExtractor.logger).to receive(:error).with(%r{Failed to fetch/parse program test-program})
        platform.fetch_programs
      end

      it 'returns empty array' do
        programs = platform.fetch_programs
        expect(programs).to be_empty
      end
    end

    context 'with multiple asset types' do
      let(:scopes_data) do
        [
          {
            'attributes' => {
              'asset_identifier' => 'example.com',
              'asset_type' => 'URL',
              'eligible_for_submission' => true,
              'eligible_for_bounty' => true
            }
          },
          {
            'attributes' => {
              'asset_identifier' => 'com.example.app',
              'asset_type' => 'GOOGLE_PLAY_APP_ID',
              'eligible_for_submission' => true,
              'eligible_for_bounty' => true
            }
          },
          {
            'attributes' => {
              'asset_identifier' => '192.168.1.0/24',
              'asset_type' => 'CIDR',
              'eligible_for_submission' => true,
              'eligible_for_bounty' => false
            }
          }
        ]
      end

      it 'maps asset types correctly' do
        programs = platform.fetch_programs
        scopes = programs.first.scopes

        expect(scopes.find { |s| s.value == 'example.com' }.type).to eq('web')
        expect(scopes.find { |s| s.value == 'com.example.app' }.type).to eq('mobile')
        expect(scopes.find { |s| s.value == '192.168.1.0/24' }.type).to eq('cidr')
      end
    end

    context 'with out-of-scope assets' do
      let(:scopes_data) do
        [
          {
            'attributes' => {
              'asset_identifier' => 'in-scope.com',
              'asset_type' => 'URL',
              'eligible_for_submission' => true,
              'eligible_for_bounty' => true
            }
          },
          {
            'attributes' => {
              'asset_identifier' => 'out-of-scope.com',
              'asset_type' => 'URL',
              'eligible_for_submission' => false,
              'eligible_for_bounty' => false
            }
          }
        ]
      end

      it 'filters out non-eligible scopes' do
        programs = platform.fetch_programs
        scopes = programs.first.scopes

        expect(scopes.size).to eq(1)
        expect(scopes.first.value).to eq('in-scope.com')
      end
    end

    context 'with normalization' do
      let(:scopes_data) do
        [
          {
            'attributes' => {
              'asset_identifier' => 'domain1.com,domain2.com',
              'asset_type' => 'URL',
              'eligible_for_submission' => true,
              'eligible_for_bounty' => true
            }
          }
        ]
      end

      before do
        allow(ScopesExtractor::Normalizer).to receive(:normalize)
          .with('hackerone', 'domain1.com,domain2.com')
          .and_return(['domain1.com', 'domain2.com'])
      end

      it 'normalizes web scopes' do
        programs = platform.fetch_programs
        scopes = programs.first.scopes

        expect(scopes.size).to eq(2)
        expect(scopes.map(&:value)).to contain_exactly('domain1.com', 'domain2.com')
      end
    end
  end
end
