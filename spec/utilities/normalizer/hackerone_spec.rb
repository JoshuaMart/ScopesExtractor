# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Normalizer::Hackerone do
  describe '.normalization' do
    context 'when input contains domains separated by comma' do
      it 'splits the input into separate domains' do
        input = 'example.tld,example.com'
        expected = ['example.tld', 'example.com']
        expect(described_class.normalization(input)).to eq(expected)
      end
    end

    context 'when input does not contain a comma' do
      it 'returns the input as a single-element array' do
        clean_inputs = [
          'domain.tld',
          '*.domain.tld',
          'https://api.domain.tld'
        ]

        clean_inputs.each do |input|
          expect(described_class.normalization(input.dup)).to eq([input])
        end
      end
    end

    context 'domain.(TLD)' do
      it 'returns domain.com' do
        input = 'domain.(TLD)'
        expected = ['domain.com']
        expect(described_class.normalization(input)).to eq(expected)
      end
    end
  end
end
