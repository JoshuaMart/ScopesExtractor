# frozen_string_literal: true

require 'spec_helper'
require 'scopes_extractor'

RSpec.describe ScopesExtractor::Validator do
  describe '.valid_web_target?' do
    context 'Web/API types' do
      it 'accepts valid domains and subdomains' do
        expect(described_class.valid_web_target?('example.com', 'web')).to be true
        expect(described_class.valid_web_target?('sub.example.com', 'web')).to be true
        expect(described_class.valid_web_target?('internet-banking.retail.dbs.in', 'web')).to be true
        expect(described_class.valid_web_target?('*.example.com', 'api')).to be true
      end

      it 'accepts valid URLs' do
        expect(described_class.valid_web_target?('https://api.test.com/v1', 'web')).to be true
        expect(described_class.valid_web_target?('http://localhost:8080', 'api')).to be true
      end

      it 'accepts IP addresses' do
        expect(described_class.valid_web_target?('1.2.3.4', 'web')).to be true
      end

      it 'rejects values without a dot' do
        expect(described_class.valid_web_target?('localhost', 'web')).to be false
        expect(described_class.valid_web_target?('internal-service', 'api')).to be false
      end

      it 'rejects values with spaces' do
        expect(described_class.valid_web_target?('example.com / path', 'web')).to be false
        expect(described_class.valid_web_target?('This is a description.', 'web')).to be false
      end

      it 'rejects values with sentence punctuation, brackets or chevrons' do
        expect(described_class.valid_web_target?('domain.com!', 'web')).to be false
        expect(described_class.valid_web_target?('check(internal)', 'web')).to be false
        expect(described_class.valid_web_target?('site.<tld>', 'web')).to be false
      end

      it 'rejects invalid wildcard usage' do
        expect(described_class.valid_web_target?('sub.*.example.com', 'web')).to be false # Internal wildcard
        expect(described_class.valid_web_target?('*.sub*.example.com', 'web')).to be false # Double wildcard
        expect(described_class.valid_web_target?('*.sub.*.example.com', 'web')).to be false # Double wildcard (subdomain)
        expect(described_class.valid_web_target?('*.example.com/path', 'web')).to be false # Wildcard with path
        expect(described_class.valid_web_target?('*.-sub.example.com', 'web')).to be false # Leading hyphen
      end

      it 'rejects descriptions in parentheses' do
        expect(described_class.valid_web_target?('*.example.com (description text)', 'web')).to be false
      end

      it 'rejects template placeholders' do
        expect(described_class.valid_web_target?('service-%username%-1.example.com', 'web')).to be false
        expect(described_class.valid_web_target?('service-pam-###.example.com', 'web')).to be false
        expect(described_class.valid_web_target?('api-{id}.example.com', 'web')).to be false
      end

      it 'allows hash in URL fragments but not in domain' do
        expect(described_class.valid_web_target?('https://example.com/app/#/dashboard', 'web')).to be true
        expect(described_class.valid_web_target?('example.com/#/dashboard', 'web')).to be true # Now allowed (hash in path)
        expect(described_class.valid_web_target?('site-###.com', 'web')).to be false
      end

      it 'allows query parameters in full URLs' do
        expect(described_class.valid_web_target?('https://app.mux.network/#/trade?chainid=42161', 'web')).to be true
      end

      it 'rejects very short values' do
        expect(described_class.valid_web_target?('a.b', 'web')).to be false
      end
    end

    context 'Other types' do
      it 'skips validation for source_code or other types' do
        expect(described_class.valid_web_target?('Just text', 'source_code')).to be true
        expect(described_class.valid_web_target?('repo-name', 'other')).to be true
      end
    end
  end
end
