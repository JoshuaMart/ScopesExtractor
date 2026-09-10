# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Notifiers::Webhook do
  subject(:notifier) { described_class.new }

  let(:url) { 'https://example.com/hooks/scopes' }
  let(:response) { double(code: 200, body: '') }

  before do
    allow(ScopesExtractor::Config).to receive_messages(
      webhook_enabled?: true,
      webhook_url: url,
      webhook_headers: {},
      webhook_events: [],
      webhook_new_scope_types: []
    )
    allow(ScopesExtractor::HTTP).to receive(:post).and_return(response)
  end

  # Captures the JSON body sent to the endpoint
  def sent_payload
    body = nil
    allow(ScopesExtractor::HTTP).to receive(:post) do |_url, options|
      body = options[:body]
      response
    end
    yield
    body && JSON.parse(body)
  end

  describe '#notify_new_program' do
    it 'posts a JSON payload describing the event' do
      payload = sent_payload do
        notifier.notify_new_program('yeswehack', 'Test Program', 'test-slug', scope_stats: { 'web' => 2 })
      end

      expect(payload).to include('event' => 'new_program')
      expect(payload['timestamp']).to match(/\A\d{4}-\d{2}-\d{2}T/)
      expect(payload['data']).to eq(
        'platform' => 'yeswehack',
        'program' => 'Test Program',
        'slug' => 'test-slug',
        'scopes_count' => 2,
        'scopes' => { 'web' => 2 }
      )
    end

    it 'sends the configured custom headers' do
      allow(ScopesExtractor::Config).to receive(:webhook_headers).and_return('Authorization' => 'Bearer secret')

      expect(ScopesExtractor::HTTP).to receive(:post).with(
        url,
        hash_including(headers: { 'Content-Type' => 'application/json', 'Authorization' => 'Bearer secret' })
      )

      notifier.notify_new_program('yeswehack', 'Test Program', 'test-slug')
    end
  end

  describe '#notify_removed_program' do
    it 'posts a removed_program event' do
      payload = sent_payload { notifier.notify_removed_program('hackerone', 'Test Program', 'test-slug') }

      expect(payload['event']).to eq('removed_program')
      expect(payload['data']).to eq('platform' => 'hackerone', 'program' => 'Test Program', 'slug' => 'test-slug')
    end
  end

  describe '#notify_new_scope' do
    it 'posts a new_scope event' do
      payload = sent_payload { notifier.notify_new_scope('intigriti', 'Test Program', 'example.com', 'web') }

      expect(payload['event']).to eq('new_scope')
      expect(payload['data']).to eq(
        'platform' => 'intigriti', 'program' => 'Test Program', 'value' => 'example.com', 'type' => 'web'
      )
    end

    it 'skips scope types that are filtered out' do
      allow(ScopesExtractor::Config).to receive(:webhook_new_scope_types).and_return(['web'])

      expect(ScopesExtractor::HTTP).not_to receive(:post)
      notifier.notify_new_scope('intigriti', 'Test Program', 'com.example.app', 'mobile')
    end
  end

  describe '#notify_removed_scope' do
    it 'posts a removed_scope event' do
      payload = sent_payload { notifier.notify_removed_scope('bugcrowd', 'Test Program', 'example.com') }

      expect(payload['event']).to eq('removed_scope')
      expect(payload['data']).to eq('platform' => 'bugcrowd', 'program' => 'Test Program', 'value' => 'example.com')
    end
  end

  describe '#notify_ignored_asset' do
    it 'posts an ignored_asset event with its reason' do
      payload = sent_payload { notifier.notify_ignored_asset('bugcrowd', 'Test Program', 'foo', 'Invalid format') }

      expect(payload['event']).to eq('ignored_asset')
      expect(payload['data']['reason']).to eq('Invalid format')
    end
  end

  describe '#notify_error' do
    it 'posts an error event' do
      payload = sent_payload { notifier.notify_error('Sync Error', 'boom') }

      expect(payload['event']).to eq('error')
      expect(payload['data']).to eq('title' => 'Sync Error', 'message' => 'boom')
    end
  end

  context 'when the webhook is disabled' do
    before { allow(ScopesExtractor::Config).to receive(:webhook_enabled?).and_return(false) }

    it 'does not send anything' do
      expect(ScopesExtractor::HTTP).not_to receive(:post)
      notifier.notify_new_program('yeswehack', 'Test Program', 'test-slug')
    end
  end

  context 'when no url is configured' do
    before { allow(ScopesExtractor::Config).to receive(:webhook_url).and_return('') }

    it 'does not send anything' do
      expect(ScopesExtractor::HTTP).not_to receive(:post)
      notifier.notify_new_program('yeswehack', 'Test Program', 'test-slug')
    end
  end

  context 'when the event is not in the configured list' do
    before { allow(ScopesExtractor::Config).to receive(:webhook_events).and_return(['new_scope']) }

    it 'does not send anything' do
      expect(ScopesExtractor::HTTP).not_to receive(:post)
      notifier.notify_new_program('yeswehack', 'Test Program', 'test-slug')
    end
  end

  context 'when the endpoint returns an error' do
    let(:response) { double(code: 500, body: 'boom') }

    it 'logs the failure without raising' do
      expect(ScopesExtractor.logger).to receive(:error).with(/Webhook notification failed: 500/)
      expect { notifier.notify_error('Sync Error', 'boom') }.not_to raise_error
    end
  end

  context 'when the request raises' do
    it 'logs the error without raising' do
      allow(ScopesExtractor::HTTP).to receive(:post).and_raise(StandardError, 'network down')

      expect(ScopesExtractor.logger).to receive(:error).with(/Webhook notification error: network down/)
      expect { notifier.notify_error('Sync Error', 'boom') }.not_to raise_error
    end
  end
end
