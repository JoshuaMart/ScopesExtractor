# frozen_string_literal: true

require 'spec_helper'
require 'scopes_extractor'

RSpec.describe ScopesExtractor::Normalizer do
  describe '.normalize' do
    context 'Global Normalization' do
      it 'handles protocols correctly' do
        expect(described_class.normalize('any', 'https://example.com')).to eq(['https://example.com'])
        expect(described_class.normalize('any', 'http://*.example.com')).to eq(['*.example.com'])
      end

      it 'removes trailing slashes and wildcards' do
        expect(described_class.normalize('any', 'example.com/')).to eq(['example.com'])
        expect(described_class.normalize('any', 'example.com/*')).to eq(['example.com'])
      end

      it 'converts leading dots to wildcards' do
        expect(described_class.normalize('any', '.example.com')).to eq(['*.example.com'])
      end

      it 'cleans up spaces after wildcards' do
        expect(described_class.normalize('any', '*. example.com')).to eq(['*.example.com'])
        expect(described_class.normalize('any', '* .example.com')).to eq(['*.example.com'])
      end

      it 'cleans up escaped slashes' do
        expect(described_class.normalize('any', 'example.com\\/path')).to eq(['example.com/path'])
      end

      it 'removes trailing backslashes' do
        expect(described_class.normalize('any', 'example.com\\')).to eq(['example.com'])
      end

      it 'downcases values' do
        expect(described_class.normalize('any', 'EXAMPLE.COM')).to eq(['example.com'])
      end
    end

    context 'YesWeHack' do
      it 'expands multi-TLD patterns' do
        input = 'portal-service.(sub1.example.tld|sub2.example.com|sub3.example.net|sub4.example.org|sub5.example.io|sub6.example.io\\/path)\\/*'
        expected = [
          'portal-service.sub1.example.tld',
          'portal-service.sub2.example.com',
          'portal-service.sub3.example.net',
          'portal-service.sub4.example.org',
          'portal-service.sub5.example.io',
          'portal-service.sub6.example.io/path'
        ]
        expect(described_class.normalize('yeswehack', input)).to eq(expected)
      end

      it 'handles multi-TLD with prefixes' do
        input = '*.example.(com|net)'
        expect(described_class.normalize('yeswehack', input)).to eq(['*.example.com', '*.example.net'])
      end
    end

    context 'Intigriti' do
      it 'fixes placeholders' do
        expect(described_class.normalize('intigriti', '* .example.com')).to eq(['*.example.com'])
        expect(described_class.normalize('intigriti', 'example.<tld>')).to eq(['example.com'])
        expect(described_class.normalize('intigriti', 'example.*')).to eq(['example.com'])
      end

      it "splits by ' / '" do
        input = 'example.com / example.net'
        expect(described_class.normalize('intigriti', input)).to eq(['example.com', 'example.net'])
      end

      it 'strips surrounding spaces' do
        expect(described_class.normalize('intigriti', '*.example.com  ')).to eq(['*.example.com'])
      end
    end

    context 'HackerOne' do
      it 'fixes placeholders' do
        expect(described_class.normalize('hackerone', 'example.*')).to eq(['example.com'])
        expect(described_class.normalize('hackerone', 'example.(tld)')).to eq(['example.com'])
      end

      it 'splits by comma' do
        input = 'example.com,example.net'
        expect(described_class.normalize('hackerone', input)).to eq(['example.com', 'example.net'])
      end
    end

    context 'Bugcrowd' do
      it 'strips description from scope name' do
        input = 'example.com - This is a description'
        expect(described_class.normalize('bugcrowd', input)).to eq(['example.com'])
      end
    end
  end
end
