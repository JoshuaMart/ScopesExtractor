# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

RSpec.describe ScopesExtractor::API do
  include Rack::Test::Methods

  def app
    ScopesExtractor::API.tap { |a| a.set :environment, :test }
  end

  before do
    ScopesExtractor::Database.connect
    ScopesExtractor::Database.reset
    ScopesExtractor::Database.migrate
  end

  describe 'GET /' do
    context 'with no scopes in database' do
      it 'returns empty array' do
        get '/'
        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/json')

        data = JSON.parse(last_response.body)
        expect(data['scopes']).to eq([])
        expect(data['count']).to eq(0)
      end
    end

    context 'with scopes in database' do
      before do
        # Insert test data
        program_id = ScopesExtractor.db[:programs].insert(
          slug: 'test-program',
          platform: 'yeswehack',
          name: 'Test Program',
          bounty: true,
          last_updated: Time.now
        )

        ScopesExtractor.db[:scopes].insert(
          program_id: program_id,
          value: '*.example.com',
          type: 'web',
          is_in_scope: true,
          created_at: Time.now
        )

        ScopesExtractor.db[:scopes].insert(
          program_id: program_id,
          value: 'com.example.app',
          type: 'mobile',
          is_in_scope: false,
          created_at: Time.now
        )
      end

      it 'returns all scopes' do
        get '/'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['count']).to eq(2)
        expect(data['scopes'].size).to eq(2)
      end

      it 'filters by platform' do
        get '/', platform: 'yeswehack'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['count']).to eq(2)
        expect(data['scopes'].all? { |s| s['platform'] == 'yeswehack' }).to be true
      end

      it 'filters by type' do
        get '/', type: 'web'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['count']).to eq(1)
        expect(data['scopes'].first['value']).to eq('*.example.com')
      end

      it 'filters by bounty status' do
        get '/', bounty: 'true'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['count']).to eq(2)
        bounty_values = [1, true]
        expect(data['scopes'].all? { |s| bounty_values.include?(s['bounty']) }).to be true
      end

      it 'filters by slug' do
        get '/', slug: 'test-program'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['count']).to eq(2)
        expect(data['scopes'].all? { |s| s['slug'] == 'test-program' }).to be true
      end

      it 'combines multiple filters' do
        get '/', platform: 'yeswehack', type: 'web', bounty: 'true'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['count']).to eq(1)
        expect(data['scopes'].first['value']).to eq('*.example.com')
      end

      it 'returns only values when values_only=true' do
        get '/', values_only: 'true'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data).to be_an(Array)
        expect(data.size).to eq(2)
        expect(data).to include('*.example.com')
        expect(data).to include('com.example.app')
      end
    end
  end

  describe 'GET /changes' do
    context 'with no history' do
      it 'returns empty array' do
        get '/changes'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['changes']).to eq([])
        expect(data['count']).to eq(0)
      end
    end

    context 'with history entries' do
      before do
        program_id = ScopesExtractor.db[:programs].insert(
          slug: 'test-program',
          platform: 'yeswehack',
          name: 'Test Program',
          bounty: true,
          last_updated: Time.now
        )

        ScopesExtractor.db[:history].insert(
          program_id: program_id,
          platform_name: 'yeswehack',
          program_name: 'Test Program',
          event_type: 'new_program',
          details: 'New program added',
          created_at: Time.now - 3600
        )

        ScopesExtractor.db[:history].insert(
          program_id: program_id,
          platform_name: 'yeswehack',
          program_name: 'Test Program',
          event_type: 'new_scope',
          details: '*.example.com',
          scope_type: 'web',
          category: 'In scope',
          created_at: Time.now - 1800
        )

        # Old entry (25 hours ago)
        ScopesExtractor.db[:history].insert(
          program_id: program_id,
          platform_name: 'yeswehack',
          program_name: 'Test Program',
          event_type: 'new_scope',
          details: 'old.example.com',
          scope_type: 'web',
          category: 'In scope',
          created_at: Time.now - (25 * 3600)
        )
      end

      it 'returns recent changes (default 24h)' do
        get '/changes'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['count']).to eq(2)
      end

      it 'accepts custom hours parameter' do
        get '/changes', hours: 1
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['count']).to eq(1)
      end

      it 'filters by platform' do
        get '/changes', platform: 'yeswehack'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['changes'].all? { |c| c['platform_name'] == 'yeswehack' }).to be true
      end

      it 'filters by event type' do
        get '/changes', type: 'new_program'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['count']).to eq(1)
        expect(data['changes'].first['event_type']).to eq('new_program')
      end

      it 'orders by created_at descending' do
        get '/changes'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        timestamps = data['changes'].map { |c| Time.parse(c['created_at'].to_s) }
        expect(timestamps).to eq(timestamps.sort.reverse)
      end

      it 'includes program_slug in response' do
        get '/changes'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['count']).to be > 0
        expect(data['changes'].first['program_slug']).to eq('test-program')
      end
    end
  end

  describe 'GET /wildcards' do
    context 'with mixed scopes' do
      before do
        program_id = ScopesExtractor.db[:programs].insert(
          slug: 'test-program',
          platform: 'yeswehack',
          name: 'Test Program',
          bounty: true,
          last_updated: Time.now
        )

        ScopesExtractor.db[:scopes].insert(
          program_id: program_id,
          value: '*.example.com',
          type: 'web',
          is_in_scope: true,
          created_at: Time.now
        )

        ScopesExtractor.db[:scopes].insert(
          program_id: program_id,
          value: 'specific.example.com',
          type: 'web',
          is_in_scope: true,
          created_at: Time.now
        )

        ScopesExtractor.db[:scopes].insert(
          program_id: program_id,
          value: '*example.org',
          type: 'web',
          is_in_scope: true,
          created_at: Time.now
        )
      end

      it 'returns only wildcard scopes' do
        get '/wildcards'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['count']).to eq(2)
        expect(data['wildcards'].all? { |w| w['value'].start_with?('*') }).to be true
      end

      it 'filters by platform' do
        get '/wildcards', platform: 'yeswehack'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['wildcards'].all? { |w| w['platform'] == 'yeswehack' }).to be true
      end

      it 'returns only values when values_only=true' do
        get '/wildcards', values_only: 'true'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data).to be_an(Array)
        expect(data.size).to eq(2)
        expect(data).to include('*.example.com')
        expect(data).to include('*example.org')
      end
    end
  end

  describe 'GET /exclusions' do
    context 'with ignored assets' do
      before do
        ScopesExtractor.db[:ignored_assets].insert(
          platform: 'yeswehack',
          program_slug: 'test-program',
          value: 'invalid.scope',
          reason: 'Invalid format',
          created_at: Time.now
        )

        ScopesExtractor.db[:ignored_assets].insert(
          platform: 'hackerone',
          program_slug: 'another-program',
          value: 'test',
          reason: 'Too short',
          created_at: Time.now - 3600
        )
      end

      it 'returns all ignored assets' do
        get '/exclusions'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['count']).to eq(2)
      end

      it 'orders by created_at descending' do
        get '/exclusions'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        timestamps = data['exclusions'].map { |e| Time.parse(e['created_at'].to_s) }
        expect(timestamps).to eq(timestamps.sort.reverse)
      end
    end

    context 'with no ignored assets' do
      it 'returns empty array' do
        get '/exclusions'
        expect(last_response).to be_ok

        data = JSON.parse(last_response.body)
        expect(data['exclusions']).to eq([])
        expect(data['count']).to eq(0)
      end
    end
  end

  describe 'Error handling' do
    it 'returns 404 for unknown routes' do
      get '/unknown'
      expect(last_response.status).to eq(404)

      data = JSON.parse(last_response.body)
      expect(data['error']).to eq('Not found')
    end
  end
end
