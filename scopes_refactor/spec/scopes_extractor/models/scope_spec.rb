# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Models::Scope do
  describe '.new' do
    it 'creates a scope with required attributes' do
      scope = described_class.new(
        value: '*.example.com',
        type: 'web',
        is_in_scope: true
      )

      expect(scope.value).to eq('*.example.com')
      expect(scope.type).to eq('web')
      expect(scope.is_in_scope).to be true
    end

    it 'creates an out-of-scope asset' do
      scope = described_class.new(
        value: 'api.example.com',
        type: 'web',
        is_in_scope: false
      )

      expect(scope.value).to eq('api.example.com')
      expect(scope.type).to eq('web')
      expect(scope.is_in_scope).to be false
    end

    it 'handles in_scope alias for is_in_scope' do
      scope = described_class.new(
        value: 'test.com',
        type: 'web',
        in_scope: true
      )

      expect(scope.is_in_scope).to be true
    end
  end

  describe '#to_h' do
    it 'converts to hash' do
      scope = described_class.new(
        value: '*.example.com',
        type: 'web',
        is_in_scope: true
      )

      hash = scope.to_h
      expect(hash).to eq(
        value: '*.example.com',
        type: 'web',
        is_in_scope: true
      )
    end
  end

  describe '#in_scope?' do
    it 'returns true for in-scope assets' do
      scope = described_class.new(value: 'test.com', type: 'web', is_in_scope: true)
      expect(scope.in_scope?).to be true
    end

    it 'returns false for out-of-scope assets' do
      scope = described_class.new(value: 'test.com', type: 'web', is_in_scope: false)
      expect(scope.in_scope?).to be false
    end
  end

  describe '#out_scope?' do
    it 'returns true for out-of-scope assets' do
      scope = described_class.new(value: 'test.com', type: 'web', is_in_scope: false)
      expect(scope.out_scope?).to be true
    end

    it 'returns false for in-scope assets' do
      scope = described_class.new(value: 'test.com', type: 'web', is_in_scope: true)
      expect(scope.out_scope?).to be false
    end
  end
end
