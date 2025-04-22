# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Normalizer::Bugcrowd do
  describe '.normalization' do
    context 'when input contains domain with description after dash' do
      it 'extracts the domain part before the dash' do
        input = '*.domain.tld - lorem ipsum'
        expect(described_class.normalization(input)).to eq(['*.domain.tld'])
      end

      it 'handles multiple domain formats with descriptions' do
        inputs_and_expected = {
          'domain.tld - lorem ipsum' => ['domain.tld'],
          'https://api.domain.tld - API endpoints' => ['https://api.domain.tld'],
          'sub.domain.tld - Multiple words after dash' => ['sub.domain.tld']
        }

        inputs_and_expected.each do |input, expected|
          expect(described_class.normalization(input)).to eq(expected)
        end
      end
    end

    context 'when input does not contain a dash' do
      it 'returns the input unchanged' do
        clean_inputs = [
          'domain.tld',
          '*.domain.tld',
          'https://api.domain.tld'
        ]

        clean_inputs.each do |input|
          expect(described_class.normalization(input)).to eq([input])
        end
      end
    end
  end
end
