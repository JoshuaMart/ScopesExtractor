# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Platforms::YesWeHack::Platform do
  let(:config) do
    {
      email: 'test@example.com',
      password: 'password123',
      otp: 'BASE32SECRET3232'
    }
  end
  let(:platform) { described_class.new(config) }
  let(:authenticator) { instance_double(ScopesExtractor::Platforms::YesWeHack::Authenticator) }

  describe '#initialize' do
    it 'accepts a config hash' do
      expect(platform.config).to eq(config)
    end
  end

  describe '#name' do
    it 'returns YesWeHack' do
      expect(platform.name).to eq('YesWeHack')
    end
  end

  describe '#valid_access?' do
    before do
      allow(ScopesExtractor::Platforms::YesWeHack::Authenticator).to receive(:new).and_return(authenticator)
    end

    context 'when authentication succeeds' do
      before do
        allow(authenticator).to receive_messages(authenticate: 'valid_token', authenticated?: true)
      end

      it 'returns true' do
        expect(platform.valid_access?).to be true
      end
    end

    context 'when authentication fails' do
      before do
        allow(authenticator).to receive(:authenticate).and_raise(StandardError.new('Auth failed'))
      end

      it 'returns false' do
        expect(platform.valid_access?).to be false
      end

      it 'retries authentication 3 times' do
        expect(ScopesExtractor::Platforms::YesWeHack::Authenticator).to receive(:new).exactly(3).times.and_return(authenticator)
        expect(authenticator).to receive(:authenticate).exactly(3).times.and_raise(StandardError.new('Auth failed'))
        platform.valid_access?
      end

      it 'logs warning for each failed attempt' do
        expect(ScopesExtractor.logger).to receive(:warn).with(%r{Authentication error on attempt 1/3}).ordered
        expect(ScopesExtractor.logger).to receive(:warn).with(%r{Authentication error on attempt 2/3}).ordered
        expect(ScopesExtractor.logger).to receive(:warn).with(%r{Authentication error on attempt 3/3}).ordered
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
          raise StandardError, 'Auth failed' if call_count < 2

          'valid_token'
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
    end
  end

  describe '#fetch_programs' do
    let(:program_fetcher) { instance_double(ScopesExtractor::Platforms::YesWeHack::ProgramFetcher) }

    before do
      allow(ScopesExtractor::Platforms::YesWeHack::Authenticator).to receive(:new).and_return(authenticator)
      allow(authenticator).to receive(:authenticate).and_return('valid_token')
      allow(ScopesExtractor::Platforms::YesWeHack::ProgramFetcher).to receive(:new).and_return(program_fetcher)
      allow(program_fetcher).to receive(:fetch_all).and_return([])
    end

    it 'authenticates before fetching' do
      expect(authenticator).to receive(:authenticate)
      platform.fetch_programs
    end

    it 'creates a program fetcher with token' do
      expect(ScopesExtractor::Platforms::YesWeHack::ProgramFetcher).to receive(:new).with('valid_token')
      platform.fetch_programs
    end

    it 'calls fetch_all on the fetcher' do
      expect(program_fetcher).to receive(:fetch_all)
      platform.fetch_programs
    end

    it 'returns programs array' do
      expect(platform.fetch_programs).to eq([])
    end

    context 'when already authenticated' do
      it 'does not authenticate again' do
        # First call authenticates
        platform.fetch_programs

        # Second call should not authenticate
        expect(authenticator).not_to receive(:authenticate)
        platform.fetch_programs
      end
    end
  end
end
