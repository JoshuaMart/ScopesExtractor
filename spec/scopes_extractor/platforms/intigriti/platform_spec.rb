# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Platforms::Intigriti::Platform do
  let(:config) { { token: 'test_token_123' } }
  let(:platform) { described_class.new(config) }

  describe '#initialize' do
    it 'accepts a config hash' do
      expect(platform).to be_a(described_class)
    end
  end

  describe '#name' do
    it 'returns Intigriti' do
      expect(platform.name).to eq('Intigriti')
    end
  end

  describe '#valid_access?' do
    context 'when token is missing' do
      let(:config) { {} }

      it 'returns false' do
        expect(platform.valid_access?).to be false
      end
    end

    context 'when token is provided' do
      context 'when API returns success' do
        let(:response) { double('Response', success?: true, code: 200) }

        before do
          allow(ScopesExtractor::HTTP).to receive(:get).and_return(response)
        end

        it 'returns true' do
          expect(platform.valid_access?).to be true
        end

        it 'logs debug message' do
          expect(ScopesExtractor.logger).to receive(:debug).with('[Intigriti] Access validation successful')
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
          expect(ScopesExtractor.logger).to receive(:error).with('[Intigriti] Access validation failed: 401')
          platform.valid_access?
        end
      end

      context 'when HTTP request raises an error' do
        it 'returns false' do
          allow(ScopesExtractor::HTTP).to receive(:get).and_raise(StandardError, 'Network error')
          expect(platform.valid_access?).to be false
        end

        it 'logs error message' do
          allow(ScopesExtractor::HTTP).to receive(:get).and_raise(StandardError, 'Network error')
          expect(ScopesExtractor.logger).to receive(:error).with('[Intigriti] Access validation error: Network error')
          platform.valid_access?
        end
      end
    end
  end

  describe '#fetch_programs' do
    let(:fetcher) { instance_double(ScopesExtractor::Platforms::Intigriti::ProgramFetcher) }
    let(:raw_programs) do
      [
        {
          'id' => '123',
          'handle' => 'test-program',
          'name' => 'Test Program',
          'maxBounty' => { 'value' => 1000 }
        }
      ]
    end
    let(:details) do
      {
        'domains' => {
          'content' => [
            {
              'endpoint' => 'example.com',
              'type' => { 'id' => 1 },
              'tier' => { 'value' => 'Critical' }
            }
          ]
        }
      }
    end

    before do
      allow(ScopesExtractor::Platforms::Intigriti::ProgramFetcher).to receive(:new).and_return(fetcher)
      allow(fetcher).to receive(:fetch_all).and_return(raw_programs)
      allow(fetcher).to receive(:fetch_details).with('123').and_return(details)
    end

    it 'creates a program fetcher with token' do
      expect(ScopesExtractor::Platforms::Intigriti::ProgramFetcher).to receive(:new).with('test_token_123')
      platform.fetch_programs
    end

    it 'fetches all programs' do
      expect(fetcher).to receive(:fetch_all)
      platform.fetch_programs
    end

    it 'fetches details for each program' do
      expect(fetcher).to receive(:fetch_details).with('123')
      platform.fetch_programs
    end

    it 'returns array of programs' do
      programs = platform.fetch_programs
      expect(programs).to be_an(Array)
      expect(programs.size).to eq(1)
      expect(programs.first).to be_a(ScopesExtractor::Models::Program)
      expect(programs.first.slug).to eq('test-program')
    end

    context 'when program is VDP and skip_vdp is true' do
      let(:raw_programs) do
        [
          {
            'id' => '123',
            'handle' => 'vdp-program',
            'name' => 'VDP Program',
            'maxBounty' => { 'value' => 0 }
          }
        ]
      end

      before do
        allow(ScopesExtractor::Config).to receive(:skip_vdp?).with('intigriti').and_return(true)
      end

      it 'skips the program' do
        programs = platform.fetch_programs
        expect(programs).to be_empty
      end

      it 'logs the skip' do
        expect(ScopesExtractor.logger).to receive(:debug).with('[Intigriti] Skipping VDP program: vdp-program')
        platform.fetch_programs
      end
    end

    context 'when fetching details fails' do
      before do
        allow(fetcher).to receive(:fetch_details).with('123').and_return(nil)
      end

      it 'skips the program' do
        programs = platform.fetch_programs
        expect(programs).to be_empty
      end
    end

    context 'when parsing fails' do
      let(:details) do
        {
          'domains' => {
            'content' => [
              {
                'endpoint' => 'example.com',
                'type' => { 'id' => 1 },
                'tier' => { 'value' => 'Critical' }
              }
            ]
          }
        }
      end

      before do
        allow(fetcher).to receive(:fetch_details).and_return(details)
        allow(platform).to receive(:parse_scope).and_raise(StandardError, 'Parse error')
      end

      it 'logs the error' do
        expect(ScopesExtractor.logger).to receive(:error).with(/Failed to parse program test-program/)
        platform.fetch_programs
      end

      it 'returns empty array' do
        programs = platform.fetch_programs
        expect(programs).to be_empty
      end
    end

    context 'with multiple scope types' do
      let(:details) do
        {
          'domains' => {
            'content' => [
              {
                'endpoint' => 'example.com',
                'type' => { 'id' => 1 },
                'tier' => { 'value' => 'Critical' }
              },
              {
                'endpoint' => 'com.example.app',
                'type' => { 'id' => 2 },
                'tier' => { 'value' => 'High' }
              },
              {
                'endpoint' => '192.168.1.0/24',
                'type' => { 'id' => 4 },
                'tier' => { 'value' => 'Medium' }
              }
            ]
          }
        }
      end

      it 'maps scope types correctly' do
        programs = platform.fetch_programs
        scopes = programs.first.scopes

        expect(scopes.find { |s| s.value == 'example.com' }.type).to eq('web')
        expect(scopes.find { |s| s.value == 'com.example.app' }.type).to eq('mobile')
        expect(scopes.find { |s| s.value == '192.168.1.0/24' }.type).to eq('cidr')
      end
    end

    context 'with out-of-scope scopes' do
      let(:details) do
        {
          'domains' => {
            'content' => [
              {
                'endpoint' => 'in-scope.com',
                'type' => { 'id' => 1 },
                'tier' => { 'value' => 'Critical' }
              },
              {
                'endpoint' => 'out-scope.com',
                'type' => { 'id' => 1 },
                'tier' => { 'value' => 'Out Of Scope' }
              }
            ]
          }
        }
      end

      it 'marks out-of-scope correctly' do
        programs = platform.fetch_programs
        scopes = programs.first.scopes

        in_scope = scopes.find { |s| s.value == 'in-scope.com' }
        out_scope = scopes.find { |s| s.value == 'out-scope.com' }

        expect(in_scope.is_in_scope).to be true
        expect(out_scope.is_in_scope).to be false
      end
    end

    context 'with No Bounty tier' do
      let(:details) do
        {
          'domains' => {
            'content' => [
              {
                'endpoint' => 'valid.com',
                'type' => { 'id' => 1 },
                'tier' => { 'value' => 'Critical' }
              },
              {
                'endpoint' => 'nobounty.com',
                'type' => { 'id' => 1 },
                'tier' => { 'value' => 'No Bounty' }
              }
            ]
          }
        }
      end

      it 'filters out No Bounty scopes' do
        programs = platform.fetch_programs
        scopes = programs.first.scopes

        expect(scopes.size).to eq(1)
        expect(scopes.first.value).to eq('valid.com')
      end
    end

    context 'with normalization' do
      let(:details) do
        {
          'domains' => {
            'content' => [
              {
                'endpoint' => 'example.com / api.example.com',
                'type' => { 'id' => 1 },
                'tier' => { 'value' => 'Critical' }
              }
            ]
          }
        }
      end

      before do
        allow(ScopesExtractor::Normalizer).to receive(:normalize)
          .with('intigriti', 'example.com / api.example.com')
          .and_return(['example.com', 'api.example.com'])
      end

      it 'normalizes web scopes' do
        programs = platform.fetch_programs
        scopes = programs.first.scopes

        expect(scopes.size).to eq(2)
        expect(scopes.map(&:value)).to contain_exactly('example.com', 'api.example.com')
      end
    end

    context 'when details has no domains' do
      let(:details) do
        { 'domains' => {} }
      end

      it 'skips the program' do
        programs = platform.fetch_programs
        expect(programs).to be_empty
      end
    end
  end
end
