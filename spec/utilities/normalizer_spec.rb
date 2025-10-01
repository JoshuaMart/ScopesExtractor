# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Normalizer do
  describe '.global_normalization' do
    context 'when input is a wildcard domain with trailing slash' do
      it 'removes the trailing slash and returns the wildcard domain' do
        input = '*.domain.tld/'
        expected = '*.domain.tld'
        expect(described_class.global_normalization(input)).to eq(expected)
      end
    end

    context 'when input is a wildcard domain with https protocol and trailing slash' do
      it 'removes the protocol and trailing slash, returns the wildcard domain' do
        input = 'https://*.domain.tld/'
        expected = '*.domain.tld'
        expect(described_class.global_normalization(input)).to eq(expected)
      end
    end
  end
end
