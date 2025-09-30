# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::ScopeCategoryDetector do
  describe '.source_code?' do
    context 'with source code URLs' do
      it 'returns true for GitHub URLs' do
        expect(described_class.source_code?('https://github.com/user/repo')).to be true
      end

      it 'returns true for Atlassian Marketplace URLs' do
        expect(described_class.source_code?('https://marketplace.atlassian.com/apps/1234')).to be true
      end
    end

    context 'with non-source code URLs' do
      it 'returns false for regular websites' do
        expect(described_class.source_code?('https://example.com')).to be false
      end

      it 'returns false for mobile app stores' do
        expect(described_class.source_code?('https://play.google.com/store/apps/details?id=com.example')).to be false
      end
    end

    context 'with invalid input' do
      it 'returns false for nil' do
        expect(described_class.source_code?(nil)).to be false
      end

      it 'returns false for empty string' do
        expect(described_class.source_code?('')).to be false
      end
    end
  end

  describe '.mobile_app?' do
    context 'with mobile app store URLs' do
      it 'returns true for Google Play Store URLs' do
        expect(described_class.mobile_app?('https://play.google.com/store/apps/details?id=com.example')).to be true
      end

      it 'returns true for iTunes Apple URLs' do
        expect(described_class.mobile_app?('https://itunes.apple.com/us/app/id123456789')).to be true
      end

      it 'returns true for Apple Apps URLs' do
        expect(described_class.mobile_app?('https://apps.apple.com/us/app/id123456789')).to be true
      end
    end

    context 'with non-mobile URLs' do
      it 'returns false for regular websites' do
        expect(described_class.mobile_app?('https://example.com')).to be false
      end

      it 'returns false for GitHub URLs' do
        expect(described_class.mobile_app?('https://github.com/user/repo')).to be false
      end
    end

    context 'with invalid input' do
      it 'returns false for nil' do
        expect(described_class.mobile_app?(nil)).to be false
      end

      it 'returns false for empty string' do
        expect(described_class.mobile_app?('')).to be false
      end
    end
  end

  describe '.other_category?' do
    context 'with Chrome Web Store URLs' do
      it 'returns true for Chrome Web Store URLs' do
        expect(described_class.other_category?('https://chromewebstore.google.com/detail/extension-name/abcdefgh')).to be true
      end
    end

    context 'with non-Chrome Web Store URLs' do
      it 'returns false for regular websites' do
        expect(described_class.other_category?('https://example.com')).to be false
      end

      it 'returns false for mobile app stores' do
        expect(described_class.other_category?('https://play.google.com/store/apps')).to be false
      end
    end

    context 'with invalid input' do
      it 'returns false for nil' do
        expect(described_class.other_category?(nil)).to be false
      end

      it 'returns false for empty string' do
        expect(described_class.other_category?('')).to be false
      end
    end
  end

  describe '.adjust_category' do
    context 'with source code URLs' do
      it 'returns :source_code for GitHub URLs regardless of initial category' do
        expect(described_class.adjust_category(:web, 'https://github.com/user/repo')).to eq(:source_code)
      end

      it 'returns :source_code for Atlassian Marketplace URLs' do
        expect(described_class.adjust_category(:other,
                                               'https://marketplace.atlassian.com/apps/1234')).to eq(:source_code)
      end
    end

    context 'with mobile app store URLs' do
      it 'returns :mobile for Google Play Store URLs' do
        expect(described_class.adjust_category(:web,
                                               'https://play.google.com/store/apps/details?id=com.example')).to eq(:mobile)
      end

      it 'returns :mobile for iTunes URLs' do
        expect(described_class.adjust_category(:other, 'https://itunes.apple.com/us/app/id123456789')).to eq(:mobile)
      end

      it 'returns :mobile for Apple Apps URLs' do
        expect(described_class.adjust_category(:web, 'https://apps.apple.com/us/app/id123456789')).to eq(:mobile)
      end
    end

    context 'with Chrome Web Store URLs' do
      it 'returns :other for Chrome Web Store URLs' do
        expect(described_class.adjust_category(:web,
                                               'https://chromewebstore.google.com/detail/extension/abcdefgh')).to eq(:other)
      end
    end

    context 'with regular URLs' do
      it 'returns the original category for regular websites' do
        expect(described_class.adjust_category(:web, 'https://example.com')).to eq(:web)
      end

      it 'preserves the original category when no special pattern matches' do
        expect(described_class.adjust_category(:executable, 'https://download.example.com/app.exe')).to eq(:executable)
      end
    end

    context 'with invalid input' do
      it 'returns the original category for nil scope' do
        expect(described_class.adjust_category(:web, nil)).to eq(:web)
      end

      it 'returns the original category for empty string' do
        expect(described_class.adjust_category(:mobile, '')).to eq(:mobile)
      end
    end

    context 'with priority of detections' do
      it 'prioritizes source_code detection over mobile' do
        # GitHub URL should be source_code even if initial category is mobile
        expect(described_class.adjust_category(:mobile, 'https://github.com/mobile/app')).to eq(:source_code)
      end

      it 'prioritizes mobile detection over other' do
        # Mobile app URL should remain mobile even if it could be other
        expect(described_class.adjust_category(:other, 'https://play.google.com/store/apps')).to eq(:mobile)
      end
    end
  end
end
