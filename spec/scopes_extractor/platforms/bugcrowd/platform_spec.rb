# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Platforms::Bugcrowd::Platform do
  let(:config) do
    {
      email: 'test@example.com',
      password: 'password123',
      otp_secret: 'BASE32SECRET3232'
    }
  end
  let(:platform) { described_class.new(config) }
  let(:authenticator) { instance_double(ScopesExtractor::Platforms::Bugcrowd::Authenticator) }

  describe '#initialize' do
    it 'accepts a config hash' do
      expect(platform.instance_variable_get(:@email)).to eq('test@example.com')
      expect(platform.instance_variable_get(:@password)).to eq('password123')
      expect(platform.instance_variable_get(:@otp_secret)).to eq('BASE32SECRET3232')
    end
  end

  describe '#name' do
    it 'returns Bugcrowd' do
      expect(platform.name).to eq('Bugcrowd')
    end
  end

  describe '#valid_access?' do
    before do
      allow(ScopesExtractor::HTTP).to receive(:clear_cookies)
      allow(ScopesExtractor::Platforms::Bugcrowd::Authenticator).to receive(:new).and_return(authenticator)
    end

    context 'when credentials are missing' do
      let(:config) { { email: nil, password: nil, otp_secret: nil } }

      it 'returns false without attempting authentication' do
        expect(authenticator).not_to receive(:authenticate)
        expect(platform.valid_access?).to be false
      end
    end

    context 'when authentication succeeds' do
      before do
        allow(authenticator).to receive(:authenticate).and_return(true)
      end

      it 'returns true' do
        expect(platform.valid_access?).to be true
      end

      it 'clears cookies before authentication' do
        expect(ScopesExtractor::HTTP).to receive(:clear_cookies)
        platform.valid_access?
      end

      it 'logs success' do
        expect(ScopesExtractor.logger).to receive(:info).with(/Authentication successful on attempt 1/)
        platform.valid_access?
      end
    end

    context 'when authentication fails' do
      before do
        allow(authenticator).to receive(:authenticate).and_return(false)
      end

      it 'returns false' do
        expect(platform.valid_access?).to be false
      end

      it 'retries authentication 3 times' do
        expect(ScopesExtractor::Platforms::Bugcrowd::Authenticator).to receive(:new).exactly(3).times.and_return(authenticator)
        expect(authenticator).to receive(:authenticate).exactly(3).times.and_return(false)
        platform.valid_access?
      end

      it 'logs warning for each failed attempt' do
        expect(ScopesExtractor.logger).to receive(:warn).with(%r{Authentication failed on attempt 1/3}).ordered
        expect(ScopesExtractor.logger).to receive(:warn).with(%r{Authentication failed on attempt 2/3}).ordered
        expect(ScopesExtractor.logger).to receive(:warn).with(%r{Authentication failed on attempt 3/3}).ordered
        expect(ScopesExtractor.logger).to receive(:error).with(/Authentication failed after 3 attempts/)
        platform.valid_access?
      end

      it 'waits 2 seconds between retries' do
        expect(platform).to receive(:sleep).with(2).twice
        platform.valid_access?
      end

      it 'clears cookies before each attempt' do
        expect(ScopesExtractor::HTTP).to receive(:clear_cookies).exactly(3).times
        platform.valid_access?
      end
    end

    context 'when authentication raises an error' do
      before do
        allow(authenticator).to receive(:authenticate).and_raise(StandardError.new('Network error'))
      end

      it 'returns false' do
        expect(platform.valid_access?).to be false
      end

      it 'retries authentication 3 times' do
        expect(ScopesExtractor::Platforms::Bugcrowd::Authenticator).to receive(:new).exactly(3).times.and_return(authenticator)
        expect(authenticator).to receive(:authenticate).exactly(3).times.and_raise(StandardError.new('Network error'))
        platform.valid_access?
      end

      it 'logs warning for each error' do
        expect(ScopesExtractor.logger).to receive(:warn).with(%r{Authentication error on attempt 1/3: Network error}).ordered
        expect(ScopesExtractor.logger).to receive(:warn).with(%r{Authentication error on attempt 2/3: Network error}).ordered
        expect(ScopesExtractor.logger).to receive(:warn).with(%r{Authentication error on attempt 3/3: Network error}).ordered
        expect(ScopesExtractor.logger).to receive(:error).with(/Authentication failed after 3 attempts/)
        platform.valid_access?
      end

      it 'waits 2 seconds between retries' do
        expect(platform).to receive(:sleep).with(2).twice
        platform.valid_access?
      end
    end

    context 'when authentication succeeds after retry' do
      before do
        call_count = 0
        allow(authenticator).to receive(:authenticate) do
          call_count += 1
          return false if call_count < 2

          true
        end
      end

      it 'returns true' do
        expect(platform.valid_access?).to be true
      end

      it 'logs success on the successful attempt' do
        allow(ScopesExtractor.logger).to receive(:warn)
        expect(ScopesExtractor.logger).to receive(:info).with(/Authentication successful on attempt 2/)
        platform.valid_access?
      end

      it 'stops retrying after success' do
        expect(ScopesExtractor::Platforms::Bugcrowd::Authenticator).to receive(:new).twice.and_return(authenticator)
        platform.valid_access?
      end
    end
  end
end
