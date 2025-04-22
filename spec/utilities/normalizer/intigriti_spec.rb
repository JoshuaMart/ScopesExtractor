# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Normalizer::Intigriti do
  describe '.normalization' do
    context 'when input contains domains separated by slash' do
      it 'splits the input into separate domains' do
        input = 'aaa.example.tld / login.example.tld / account.example.tld'
        expected = ['aaa.example.tld', 'login.example.tld', 'account.example.tld']
        expect(described_class.normalization(input)).to eq(expected)
      end

      it 'handles various domain formats separated by slashes' do
        inputs_and_expected = {
          'example.tld / example.xyz' => ['example.tld', 'example.xyz'],
          'example.tld / example.xyz / example.com' => ['example.tld', 'example.xyz', 'example.com']
        }

        inputs_and_expected.each do |input, expected|
          expect(described_class.normalization(input)).to eq(expected)
        end
      end
    end

    context 'when input contains wildcards' do
      it 'correctly formats wildcard domains' do
        inputs_and_expected = {
          '*. domain.tld' => ['*.domain.tld'],
          '* .domain.tld' => ['*.domain.tld'],
          '* domain.tld' => ['*.domain.tld']
        }

        inputs_and_expected.each do |input, expected|
          expect(described_class.normalization(input.dup)).to eq(expected)
        end
      end
    end

    context 'when input does not contain a slash' do
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
  end
end
