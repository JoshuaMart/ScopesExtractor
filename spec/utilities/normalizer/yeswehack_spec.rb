# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Normalizer::YesWeHack do
  describe '.normalization' do
    context 'when input contains excluded patterns' do
      it 'returns an empty array' do
        excluded_inputs = [
          'endpoints on our sites',
          'special scenarios',
          'core services',
          'see program description',
          'see description'
        ]

        excluded_inputs.each do |input|
          expect(described_class.normalization(input)).to eq([])
        end
      end
    end

    context 'when input contains multiple TLDs in parentheses' do
      it 'expands into multiple domains with different TLDs' do
        input = '*.example.(com|org|net)'
        expected = ['*.example.com', '*.example.org', '*.example.net']
        expect(described_class.normalization(input)).to match_array(expected)
      end

      it 'handles https prefix correctly' do
        input = 'https://example.(com|org)'
        expected = ['https://example.com', 'https://example.org']
        expect(described_class.normalization(input)).to match_array(expected)
      end
    end

    context 'when input does not match any special patterns' do
      it 'returns the input value unchanged' do
        input = 'example.com'
        expect(described_class.normalization(input)).to eq([input])
      end
    end
  end

  describe '.excluded_pattern?' do
    it 'returns true when the value contains an excluded pattern' do
      expect(described_class.excluded_pattern?('This is about core services and more')).to be true
    end

    it 'returns false when the value does not contain an excluded pattern' do
      expect(described_class.excluded_pattern?('example.com')).to be false
    end
  end
end
