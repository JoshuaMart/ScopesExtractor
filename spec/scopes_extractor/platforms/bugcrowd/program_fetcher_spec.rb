# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Platforms::Bugcrowd::ProgramFetcher do
  let(:fetcher) { described_class.new }

  describe '#initialize' do
    it 'creates an instance' do
      expect(fetcher).to be_a(described_class)
    end
  end

  describe '#fetch_all' do
    context 'with single page of programs' do
      let(:response_body) do
        {
          'engagements' => [
            { 'code' => 'program1', 'accessStatus' => 'open' },
            { 'code' => 'program2', 'accessStatus' => 'open' },
            { 'code' => 'program3', 'accessStatus' => 'closed' }
          ]
        }.to_json
      end
      let(:response) { double('Response', success?: true, code: 200, body: response_body) }
      let(:empty_response) { double('Response', success?: true, code: 200, body: { 'engagements' => [] }.to_json) }

      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('page=1'))
          .and_return(response)
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('page=2'))
          .and_return(empty_response)
      end

      it 'fetches all open programs' do
        programs = fetcher.fetch_all
        expect(programs.size).to eq(2)
        expect(programs.all? { |p| p['accessStatus'] == 'open' }).to be true
      end

      it 'filters out closed programs' do
        programs = fetcher.fetch_all
        expect(programs.none? { |p| p['code'] == 'program3' }).to be true
      end

      it 'logs the fetch operation' do
        expect(ScopesExtractor.logger).to receive(:debug).with('[Bugcrowd] Fetching bug_bounty engagements page 1')
        expect(ScopesExtractor.logger).to receive(:debug).with('[Bugcrowd] Fetched 2 open programs from page 1')
        expect(ScopesExtractor.logger).to receive(:debug).with('[Bugcrowd] Fetching bug_bounty engagements page 2')
        expect(ScopesExtractor.logger).to receive(:info).with('[Bugcrowd] Fetched total of 2 program(s)')
        fetcher.fetch_all
      end
    end

    context 'with multiple pages of programs' do
      let(:page1_response) do
        {
          'engagements' => [
            { 'code' => 'program1', 'accessStatus' => 'open' }
          ]
        }.to_json
      end
      let(:page2_response) do
        {
          'engagements' => [
            { 'code' => 'program2', 'accessStatus' => 'open' }
          ]
        }.to_json
      end
      let(:empty_response) { double('Response', success?: true, code: 200, body: { 'engagements' => [] }.to_json) }

      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('page=1'))
          .and_return(double('Response', success?: true, code: 200, body: page1_response))
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('page=2'))
          .and_return(double('Response', success?: true, code: 200, body: page2_response))
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('page=3'))
          .and_return(empty_response)
      end

      it 'fetches all pages' do
        programs = fetcher.fetch_all
        expect(programs.size).to eq(2)
      end

      it 'logs each page fetch' do
        expect(ScopesExtractor.logger).to receive(:debug).with('[Bugcrowd] Fetching bug_bounty engagements page 1')
        expect(ScopesExtractor.logger).to receive(:debug).with('[Bugcrowd] Fetched 1 open programs from page 1')
        expect(ScopesExtractor.logger).to receive(:debug).with('[Bugcrowd] Fetching bug_bounty engagements page 2')
        expect(ScopesExtractor.logger).to receive(:debug).with('[Bugcrowd] Fetched 1 open programs from page 2')
        expect(ScopesExtractor.logger).to receive(:debug).with('[Bugcrowd] Fetching bug_bounty engagements page 3')
        expect(ScopesExtractor.logger).to receive(:info).with('[Bugcrowd] Fetched total of 2 program(s)')
        fetcher.fetch_all
      end
    end

    context 'when API returns empty data' do
      let(:response) { double('Response', success?: true, code: 200, body: { 'engagements' => [] }.to_json) }

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
        expect { fetcher.fetch_all }.to raise_error(StandardError, /Failed to fetch engagements page 1/)
      end
    end
  end

  describe '#fetch_scopes' do
    context 'with engagement-type program' do
      let(:brief_url) { '/engagements/test-program' }
      let(:page_response) do
        double('Response',
               success?: true,
               code: 200,
               body: '<html>changelog/abc-def-123</html>')
      end
      let(:changelog_response) do
        {
          'data' => {
            'scope' => [
              {
                'name' => 'Web Application',
                'targets' => [
                  { 'name' => 'example.com', 'category' => 'website' },
                  { 'name' => 'api.example.com', 'category' => 'api' }
                ]
              },
              {
                'name' => 'Out of Scope',
                'targets' => [
                  { 'name' => 'admin.example.com', 'category' => 'website' }
                ]
              }
            ]
          }
        }.to_json
      end

      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with('https://bugcrowd.com/engagements/test-program')
          .and_return(page_response)
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with('https://bugcrowd.com/engagements/test-program/changelog/abc-def-123.json')
          .and_return(double('Response', success?: true, code: 200, body: changelog_response))
      end

      it 'fetches scopes from changelog' do
        scopes = fetcher.fetch_scopes(brief_url)
        expect(scopes.size).to eq(2)
        expect(scopes.map { |s| s['name'] }).to contain_exactly('example.com', 'api.example.com')
      end

      it 'filters out out-of-scope targets' do
        scopes = fetcher.fetch_scopes(brief_url)
        expect(scopes.none? { |s| s['name'] == 'admin.example.com' }).to be true
      end

      context 'when page fetch fails' do
        before do
          allow(ScopesExtractor::HTTP).to receive(:get)
            .with('https://bugcrowd.com/engagements/test-program')
            .and_return(double('Response', success?: false, code: 404))
        end

        it 'returns empty array' do
          scopes = fetcher.fetch_scopes(brief_url)
          expect(scopes).to be_empty
        end

        it 'logs debug message' do
          expect(ScopesExtractor.logger).to receive(:debug).with(/Failed to fetch engagement page/)
          fetcher.fetch_scopes(brief_url)
        end
      end

      context 'when changelog ID extraction fails' do
        before do
          allow(ScopesExtractor::HTTP).to receive(:get)
            .with('https://bugcrowd.com/engagements/test-program')
            .and_return(double('Response', success?: true, code: 200, body: '<html>No changelog</html>'))
        end

        it 'returns empty array' do
          scopes = fetcher.fetch_scopes(brief_url)
          expect(scopes).to be_empty
        end

        it 'logs debug message' do
          expect(ScopesExtractor.logger).to receive(:debug).with(/Failed to extract changelog ID/)
          fetcher.fetch_scopes(brief_url)
        end
      end

      context 'when changelog fetch fails' do
        before do
          allow(ScopesExtractor::HTTP).to receive(:get)
            .with('https://bugcrowd.com/engagements/test-program')
            .and_return(page_response)
          allow(ScopesExtractor::HTTP).to receive(:get)
            .with('https://bugcrowd.com/engagements/test-program/changelog/abc-def-123.json')
            .and_return(double('Response', success?: false, code: 404))
        end

        it 'returns empty array' do
          scopes = fetcher.fetch_scopes(brief_url)
          expect(scopes).to be_empty
        end

        it 'logs debug message' do
          expect(ScopesExtractor.logger).to receive(:debug).with(/Failed to fetch changelog/)
          fetcher.fetch_scopes(brief_url)
        end
      end
    end

    context 'with group-type program' do
      let(:brief_url) { '/test-program' }
      let(:groups_response) do
        {
          'groups' => [
            {
              'in_scope' => true,
              'targets_url' => '/test-program/targets/1'
            },
            {
              'in_scope' => false,
              'targets_url' => '/test-program/targets/2'
            }
          ]
        }.to_json
      end
      let(:targets_response) do
        {
          'targets' => [
            { 'name' => 'example.com', 'category' => 'website' },
            { 'name' => '*.example.com', 'category' => 'website' }
          ]
        }.to_json
      end

      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with('https://bugcrowd.com/test-program/target_groups', headers: { 'Accept' => 'application/json' })
          .and_return(double('Response', success?: true, code: 200, body: groups_response))
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with('https://bugcrowd.com/test-program/targets/1', headers: { 'Accept' => 'application/json' })
          .and_return(double('Response', success?: true, code: 200, body: targets_response))
      end

      it 'fetches scopes from target groups' do
        scopes = fetcher.fetch_scopes(brief_url)
        expect(scopes.size).to eq(2)
        expect(scopes.map { |s| s['name'] }).to contain_exactly('example.com', '*.example.com')
      end

      it 'only fetches in-scope groups' do
        expect(ScopesExtractor::HTTP).not_to receive(:get)
          .with('https://bugcrowd.com/test-program/targets/2', any_args)
        fetcher.fetch_scopes(brief_url)
      end

      context 'when target groups fetch fails' do
        before do
          allow(ScopesExtractor::HTTP).to receive(:get)
            .with('https://bugcrowd.com/test-program/target_groups', headers: { 'Accept' => 'application/json' })
            .and_return(double('Response', success?: false, code: 404))
        end

        it 'returns empty array' do
          scopes = fetcher.fetch_scopes(brief_url)
          expect(scopes).to be_empty
        end

        it 'logs debug message' do
          expect(ScopesExtractor.logger).to receive(:debug).with(/Failed to fetch target groups/)
          fetcher.fetch_scopes(brief_url)
        end
      end

      context 'when targets fetch fails' do
        before do
          allow(ScopesExtractor::HTTP).to receive(:get)
            .with('https://bugcrowd.com/test-program/target_groups', headers: { 'Accept' => 'application/json' })
            .and_return(double('Response', success?: true, code: 200, body: groups_response))
          allow(ScopesExtractor::HTTP).to receive(:get)
            .with('https://bugcrowd.com/test-program/targets/1', headers: { 'Accept' => 'application/json' })
            .and_return(double('Response', success?: false, code: 404))
        end

        it 'skips failed groups' do
          scopes = fetcher.fetch_scopes(brief_url)
          expect(scopes).to be_empty
        end
      end
    end

    context 'with OOS marker variations' do
      let(:brief_url) { '/engagements/test-program' }
      let(:page_response) do
        double('Response',
               success?: true,
               code: 200,
               body: '<html>changelog/abc-def-123</html>')
      end
      let(:changelog_response) do
        {
          'data' => {
            'scope' => [
              {
                'name' => 'In Scope',
                'targets' => [{ 'name' => 'in.example.com' }]
              },
              {
                'name' => 'OOS - Do not test',
                'targets' => [{ 'name' => 'oos1.example.com' }]
              },
              {
                'name' => 'Out of Scope Items',
                'targets' => [{ 'name' => 'oos2.example.com' }]
              }
            ]
          }
        }.to_json
      end

      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with('https://bugcrowd.com/engagements/test-program')
          .and_return(page_response)
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with('https://bugcrowd.com/engagements/test-program/changelog/abc-def-123.json')
          .and_return(double('Response', success?: true, code: 200, body: changelog_response))
      end

      it 'filters out all OOS variations' do
        scopes = fetcher.fetch_scopes(brief_url)
        expect(scopes.size).to eq(1)
        expect(scopes.first['name']).to eq('in.example.com')
      end
    end
  end
end
