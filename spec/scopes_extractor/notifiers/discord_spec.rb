# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Notifiers::Discord do
  let(:notifier) { described_class.new }

  before do
    # Stub HTTP calls
    allow(ScopesExtractor::HTTP).to receive(:post).and_return(
      double(code: 200, headers: {}, body: '{}')
    )
  end

  describe '#notify_new_program' do
    context 'when discord is enabled and event is configured' do
      before do
        allow(ScopesExtractor::Config).to receive_messages(discord_enabled?: true, discord_events: ['new_program'], discord_main_webhook: { url: 'https://discord.webhook/main' })
      end

      it 'sends a notification' do
        expect(ScopesExtractor::HTTP).to receive(:post).with(
          'https://discord.webhook/main',
          hash_including(body: a_string_including('New Program'))
        )

        notifier.notify_new_program('yeswehack', 'Test Program', 'test-slug')
      end
    end

    context 'when discord is disabled' do
      before do
        allow(ScopesExtractor::Config).to receive(:discord_enabled?).and_return(false)
      end

      it 'does not send a notification' do
        expect(ScopesExtractor::HTTP).not_to receive(:post)
        notifier.notify_new_program('yeswehack', 'Test Program', 'test-slug')
      end
    end

    context 'when event is not configured' do
      before do
        allow(ScopesExtractor::Config).to receive_messages(discord_enabled?: true, discord_events: ['removed_program'], discord_main_webhook: { url: 'https://discord.webhook/main' })
      end

      it 'does not send a notification' do
        expect(ScopesExtractor::HTTP).not_to receive(:post)
        notifier.notify_new_program('yeswehack', 'Test Program', 'test-slug')
      end
    end
  end

  describe '#notify_new_scope' do
    context 'when scope type is in filter list' do
      before do
        allow(ScopesExtractor::Config).to receive_messages(discord_enabled?: true, discord_events: ['new_scope'], discord_new_scope_types: ['web'], discord_main_webhook: { url: 'https://discord.webhook/main' })
      end

      it 'sends a notification' do
        expect(ScopesExtractor::HTTP).to receive(:post)
        notifier.notify_new_scope('yeswehack', 'Test Program', '*.example.com', 'web')
      end
    end

    context 'when scope type is not in filter list' do
      before do
        allow(ScopesExtractor::Config).to receive_messages(discord_enabled?: true, discord_events: ['new_scope'], discord_new_scope_types: ['web'], discord_main_webhook: { url: 'https://discord.webhook/main' })
      end

      it 'does not send a notification' do
        expect(ScopesExtractor::HTTP).not_to receive(:post)
        notifier.notify_new_scope('yeswehack', 'Test Program', 'com.example.app', 'mobile')
      end
    end

    context 'when filter list is empty' do
      before do
        allow(ScopesExtractor::Config).to receive_messages(discord_enabled?: true, discord_events: ['new_scope'], discord_new_scope_types: [], discord_main_webhook: { url: 'https://discord.webhook/main' })
      end

      it 'sends notifications for all types' do
        expect(ScopesExtractor::HTTP).to receive(:post).twice

        notifier.notify_new_scope('yeswehack', 'Test Program', '*.example.com', 'web')
        notifier.notify_new_scope('yeswehack', 'Test Program', 'com.example.app', 'mobile')
      end
    end
  end

  describe '#notify_error' do
    context 'when error webhook is configured' do
      before do
        allow(ScopesExtractor::Config).to receive_messages(discord_enabled?: true, discord_errors_webhook: { url: 'https://discord.webhook/errors' })
      end

      it 'sends error notification to error webhook' do
        expect(ScopesExtractor::HTTP).to receive(:post).with(
          'https://discord.webhook/errors',
          hash_including(body: a_string_including('Test Error'))
        )

        notifier.notify_error('Test Error', 'Error details')
      end
    end
  end

  describe 'rate limiting' do
    before do
      allow(ScopesExtractor::Config).to receive_messages(discord_enabled?: true, discord_events: ['new_program'], discord_main_webhook: { url: 'https://discord.webhook/main' }, discord_new_scope_types: [], discord_errors_webhook: { url: '' })
    end

    context 'when rate limit is hit' do
      it 'updates rate limit cache and sleeps' do
        response = double(
          code: 200,
          headers: {
            'X-RateLimit-Remaining' => '0',
            'X-RateLimit-Reset-After' => '1.0'
          },
          body: '{}'
        )

        allow(ScopesExtractor::HTTP).to receive(:post).and_return(response)

        expect do
          notifier.notify_new_program('yeswehack', 'Test', 'test')
        end.not_to raise_error
      end
    end

    context 'when 429 is returned' do
      it 'handles retry after without error' do
        response = double(
          code: 429,
          headers: {},
          body: '{"retry_after": 0.5}'
        )

        allow(ScopesExtractor::HTTP).to receive(:post).and_return(response)

        expect do
          notifier.notify_new_program('yeswehack', 'Test', 'test')
        end.not_to raise_error
      end
    end
  end
end
