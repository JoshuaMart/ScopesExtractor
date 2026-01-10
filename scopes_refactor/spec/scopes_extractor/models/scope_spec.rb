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

  describe 'auto-heuristic type detection' do
    it 'detects CIDR notation and overrides platform type' do
      scope = described_class.new(value: '192.168.1.0/24', type: 'web', is_in_scope: true)
      expect(scope.type).to eq('cidr')
    end

    it 'detects GitHub URLs as source_code' do
      scope = described_class.new(value: 'https://github.com/user/repo', type: 'web', is_in_scope: true)
      expect(scope.type).to eq('source_code')
    end

    it 'detects GitLab URLs as source_code' do
      scope = described_class.new(value: 'https://gitlab.com/user/project', type: 'other', is_in_scope: true)
      expect(scope.type).to eq('source_code')
    end

    it 'detects App Store URLs as mobile' do
      scope = described_class.new(value: 'https://apps.apple.com/app/id123456', type: 'web', is_in_scope: true)
      expect(scope.type).to eq('mobile')
    end

    it 'detects Play Store URLs as mobile' do
      scope = described_class.new(value: 'https://play.google.com/store/apps/details?id=com.app', type: 'other', is_in_scope: true)
      expect(scope.type).to eq('mobile')
    end

    it 'detects Chrome Web Store URLs as executable' do
      scope = described_class.new(value: 'https://chrome.google.com/webstore/detail/extension', type: 'web', is_in_scope: true)
      expect(scope.type).to eq('executable')
    end

    it 'detects Atlassian Marketplace URLs as source_code' do
      scope = described_class.new(value: 'https://marketplace.atlassian.com/apps/1234/app-name', type: 'web', is_in_scope: true)
      expect(scope.type).to eq('source_code')
    end

    it 'detects wildcards as web' do
      scope = described_class.new(value: '*.example.com', type: 'other', is_in_scope: true)
      expect(scope.type).to eq('web')
    end

    it 'keeps platform type when no heuristic matches' do
      scope = described_class.new(value: 'com.example.app', type: 'mobile', is_in_scope: true)
      expect(scope.type).to eq('mobile')
    end

    it 'keeps other type when no heuristic matches' do
      scope = described_class.new(value: 'example.com', type: 'other', is_in_scope: true)
      expect(scope.type).to eq('other')
    end

    it 'keeps web type when no heuristic matches' do
      scope = described_class.new(value: 'example.com', type: 'web', is_in_scope: true)
      expect(scope.type).to eq('web')
    end
  end
end
