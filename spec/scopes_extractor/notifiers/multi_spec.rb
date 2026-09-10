# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Notifiers::Multi do
  subject(:notifier) { described_class.new([first, second]) }

  let(:first) { double('Notifier') }
  let(:second) { double('Notifier') }

  it 'forwards notifications to every notifier' do
    expect(first).to receive(:notify_new_scope).with('yeswehack', 'Program', 'example.com', 'web')
    expect(second).to receive(:notify_new_scope).with('yeswehack', 'Program', 'example.com', 'web')

    notifier.notify_new_scope('yeswehack', 'Program', 'example.com', 'web')
  end

  it 'forwards keyword arguments' do
    expect(first).to receive(:notify_new_program).with('yeswehack', 'Program', 'slug', scope_stats: { 'web' => 1 })
    expect(second).to receive(:notify_new_program).with('yeswehack', 'Program', 'slug', scope_stats: { 'web' => 1 })

    notifier.notify_new_program('yeswehack', 'Program', 'slug', scope_stats: { 'web' => 1 })
  end

  it 'keeps notifying the others when one fails' do
    allow(first).to receive(:notify_error).and_raise(StandardError, 'boom')
    expect(second).to receive(:notify_error).with('Sync Error', 'boom')
    expect(ScopesExtractor.logger).to receive(:error).with(/notify_error failed: boom/)

    expect { notifier.notify_error('Sync Error', 'boom') }.not_to raise_error
  end

  describe '.default' do
    it 'builds the Discord and Webhook notifiers' do
      expect(described_class.default).to be_a(described_class)
    end
  end
end
