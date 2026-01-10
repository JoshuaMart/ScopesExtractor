# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Models::Program do
  let(:in_scope) do
    ScopesExtractor::Models::Scope.new(value: '*.example.com', type: 'web', is_in_scope: true)
  end

  let(:out_scope) do
    ScopesExtractor::Models::Scope.new(value: 'test.example.com', type: 'web', is_in_scope: false)
  end

  describe '.new' do
    it 'creates a program without id' do
      program = described_class.new(
        slug: 'test-program',
        platform: 'hackerone',
        name: 'Test Program',
        bounty: true,
        scopes: [in_scope]
      )

      expect(program.id).to be_nil
      expect(program.slug).to eq('test-program')
      expect(program.platform).to eq('hackerone')
      expect(program.name).to eq('Test Program')
      expect(program.bounty).to be true
      expect(program.scopes.size).to eq(1)
    end

    it 'creates a program with id' do
      program = described_class.new(
        id: 42,
        slug: 'test-program',
        platform: 'yeswehack',
        name: 'Test Program',
        bounty: false,
        scopes: []
      )

      expect(program.id).to eq(42)
      expect(program.bounty).to be false
    end

    it 'creates a program with default empty scopes' do
      program = described_class.new(
        slug: 'test-program',
        platform: 'hackerone',
        name: 'Test Program',
        bounty: true
      )

      expect(program.scopes).to eq([])
    end
  end

  describe '#in_scopes' do
    it 'returns only in-scope assets' do
      program = described_class.new(
        slug: 'test',
        platform: 'hackerone',
        name: 'Test',
        bounty: true,
        scopes: [in_scope, out_scope]
      )

      expect(program.in_scopes).to eq([in_scope])
    end

    it 'returns empty array when no in-scopes' do
      program = described_class.new(
        slug: 'test',
        platform: 'hackerone',
        name: 'Test',
        bounty: true,
        scopes: [out_scope]
      )

      expect(program.in_scopes).to eq([])
    end
  end

  describe '#out_scopes' do
    it 'returns only out-of-scope assets' do
      program = described_class.new(
        slug: 'test',
        platform: 'hackerone',
        name: 'Test',
        bounty: true,
        scopes: [in_scope, out_scope]
      )

      expect(program.out_scopes).to eq([out_scope])
    end

    it 'returns empty array when no out-scopes' do
      program = described_class.new(
        slug: 'test',
        platform: 'hackerone',
        name: 'Test',
        bounty: true,
        scopes: [in_scope]
      )

      expect(program.out_scopes).to eq([])
    end
  end

  describe '#to_h' do
    it 'converts to hash with scopes' do
      program = described_class.new(
        id: 1,
        slug: 'test',
        platform: 'hackerone',
        name: 'Test Program',
        bounty: true,
        scopes: [in_scope]
      )

      hash = program.to_h
      expect(hash[:id]).to eq(1)
      expect(hash[:slug]).to eq('test')
      expect(hash[:platform]).to eq('hackerone')
      expect(hash[:name]).to eq('Test Program')
      expect(hash[:bounty]).to be true
      expect(hash[:scopes]).to be_an(Array)
      expect(hash[:scopes].first).to eq(in_scope.to_h)
    end
  end
end
