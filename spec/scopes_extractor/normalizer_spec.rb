# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Normalizer do
  describe '.normalize' do
    context 'with global normalization' do
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

    context 'with YesWeHack platform' do
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

      it 'handles multi-TLD without prefix' do
        input = 'example.(com|net|org)'
        expect(described_class.normalize('yeswehack', input)).to eq(['example.com', 'example.net', 'example.org'])
      end

      it 'expands alternatives at the beginning of a hostname' do
        input = '(navigate|engage|checkout|internal|cached-api|api).shoppingapp.decathlon.com'
        expect(described_class.normalize('yeswehack', input)).to eq(
          %w[navigate engage checkout internal cached-api api].map { |name| "#{name}.shoppingapp.decathlon.com" }
        )

        expect(described_class.normalize('yeswehack', '(se|fi|uk).bingo.com')).to eq(
          %w[se.bingo.com fi.bingo.com uk.bingo.com]
        )
      end

      it 'expands alternatives inside a hostname while preserving the URL path' do
        input = 'https://api-(global|eu|sg|cn).decathlon.net/connect'
        expect(described_class.normalize('yeswehack', input)).to eq(
          %w[global eu sg cn].map { |region| "https://api-#{region}.decathlon.net/connect" }
        )
      end

      it 'removes soft hyphens before expanding multi-part TLDs' do
        tlds = %w[com it se co.uk be nl dk ro ee ie com.au mt]
        %w[payment www].each do |subdomain|
          input = "#{subdomain}.unibet.(com\u00AD|it|se|co.uk|be|nl|dk|ro|ee|ie|com.au|mt)"
          expect(described_class.normalize('yeswehack', input)).to eq(
            tlds.map { |tld| "#{subdomain}.unibet.#{tld}" }
          )
        end
      end

      it 'expands only the explicit entries in a bracketed list' do
        input = 'https://[it | fr | us | sg | …].louisvuitton.com'
        expect(described_class.normalize('yeswehack', input)).to eq(
          %w[it fr us sg].map { |country| "https://#{country}.louisvuitton.com" }
        )
      end

      it 'does not expand alternatives outside a hostname or across a hostname boundary' do
        expect(described_class.normalize('yeswehack', 'https://example.com/(one|two)')).to eq(
          ['https://example.com/(one|two)']
        )
        expect(described_class.normalize('yeswehack', 'https://example.com?q=(a|b)')).to eq(
          ['https://example.com?q=(a|b)']
        )
        expect(described_class.normalize('yeswehack', 'https://api-(foo/bar|baz).example.com')).to eq(
          ['https://api-(foo/bar|baz).example.com']
        )
        expect(described_class.normalize('yeswehack', 'example.com (production only)')).to eq(
          ['example.com (production only)']
        )
      end
    end

    context 'with Intigriti platform' do
      it 'replaces <tld> with .com' do
        input = '*.example.<tld>'
        expect(described_class.normalize('intigriti', input)).to eq(['*.example.com'])
      end

      it 'replaces <TLD> with .com (case insensitive)' do
        input = '*.example.<TLD>'
        expect(described_class.normalize('intigriti', input)).to eq(['*.example.com'])
      end

      it 'replaces .* with .com' do
        input = '*.example.*'
        expect(described_class.normalize('intigriti', input)).to eq(['*.example.com'])
      end

      it 'splits values with slash separator' do
        input = 'www.example.kz / www.example.com'
        expect(described_class.normalize('intigriti', input)).to eq(['www.example.kz', 'www.example.com'])
      end

      it 'handles multiple slash separators' do
        input = 'site1.com / site2.net / site3.org'
        expect(described_class.normalize('intigriti', input)).to eq(['site1.com', 'site2.net', 'site3.org'])
      end

      it 'combines <tld> replacement and slash splitting' do
        input = '*.example.<tld> / *.test.com'
        expect(described_class.normalize('intigriti', input)).to eq(['*.example.com', '*.test.com'])
      end

      it 'returns single value when no special patterns' do
        input = '*.example.com'
        expect(described_class.normalize('intigriti', input)).to eq(['*.example.com'])
      end
    end

    context 'with HackerOne platform' do
      it 'replaces .* with .com' do
        input = '*.example.*'
        expect(described_class.normalize('hackerone', input)).to eq(['*.example.com'])
      end

      it 'replaces .(TLD) with .com' do
        input = '*.example.(TLD)'
        expect(described_class.normalize('hackerone', input)).to eq(['*.example.com'])
      end

      it 'replaces .(tld) with .com (case insensitive)' do
        input = '*.example.(tld)'
        expect(described_class.normalize('hackerone', input)).to eq(['*.example.com'])
      end

      it 'splits values with comma separator' do
        input = 'site1.com,site2.net,site3.org'
        expect(described_class.normalize('hackerone', input)).to eq(['site1.com', 'site2.net', 'site3.org'])
      end

      it 'combines .(TLD) replacement and comma splitting' do
        input = '*.example.(TLD),*.test.com'
        expect(described_class.normalize('hackerone', input)).to eq(['*.example.com', '*.test.com'])
      end

      it 'returns single value when no special patterns' do
        input = '*.example.com'
        expect(described_class.normalize('hackerone', input)).to eq(['*.example.com'])
      end
    end
  end
end
