# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Platforms::Bugcrowd::Authenticator do
  let(:email) { 'test@example.com' }
  let(:password) { 'test_password' }
  let(:otp_secret) { 'BASE32SECRET' }
  let(:authenticator) { described_class.new(email: email, password: password, otp_secret: otp_secret) }

  describe '#initialize' do
    it 'sets email' do
      expect(authenticator.instance_variable_get(:@email)).to eq(email)
    end

    it 'starts unauthenticated' do
      expect(authenticator.authenticated?).to be false
    end
  end

  describe '#authenticated?' do
    it 'returns false initially' do
      expect(authenticator.authenticated?).to be false
    end
  end

  describe '#authenticate' do
    let(:login_page_response) do
      double('Response',
             success?: true,
             code: 200,
             headers: { 'Set-Cookie' => 'csrf-token=test_csrf_token; Path=/' },
             body: '<html></html>')
    end
    let(:login_response) { double('Response', success?: false, code: 422) }
    let(:otp_response) do
      double('Response',
             success?: true,
             code: 200,
             body: { redirect_to: 'https://bugcrowd.com/auth/callback' }.to_json)
    end
    let(:redirect_response) { double('Response', success?: true, code: 200, headers: {}) }
    let(:dashboard_response) do
      double('Response',
             success?: true,
             code: 200,
             body: '<html><title>Dashboard - Bugcrowd</title></html>')
    end

    context 'when credentials are missing' do
      context 'when email is missing' do
        let(:email) { nil }

        it 'returns false' do
          expect(authenticator.authenticate).to be false
        end

        it 'logs error message' do
          expect(ScopesExtractor.logger).to receive(:error)
            .with('[Bugcrowd] Missing credentials (email, password, or OTP secret)')
          authenticator.authenticate
        end
      end

      context 'when password is missing' do
        let(:password) { nil }

        it 'returns false' do
          expect(authenticator.authenticate).to be false
        end
      end

      context 'when OTP secret is missing' do
        let(:otp_secret) { nil }

        it 'returns false' do
          expect(authenticator.authenticate).to be false
        end
      end
    end

    context 'when authentication flow succeeds' do
      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('identity.bugcrowd.com/login'))
          .and_return(login_page_response)
        allow(ScopesExtractor::HTTP).to receive(:post)
          .with(include('identity.bugcrowd.com/login'), any_args)
          .and_return(login_response)
        allow(ScopesExtractor::HTTP).to receive(:post)
          .with(include('otp-challenge'), any_args)
          .and_return(otp_response)
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with('https://bugcrowd.com/auth/callback')
          .and_return(redirect_response)
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with('https://bugcrowd.com/dashboard')
          .and_return(dashboard_response)
      end

      it 'returns true' do
        expect(authenticator.authenticate).to be true
      end

      it 'sets authenticated to true' do
        authenticator.authenticate
        expect(authenticator.authenticated?).to be true
      end

      it 'logs debug messages' do
        expect(ScopesExtractor.logger).to receive(:debug).with('[Bugcrowd] Starting authentication flow')
        expect(ScopesExtractor.logger).to receive(:debug).with(/CSRF token extracted/)
        expect(ScopesExtractor.logger).to receive(:debug).with('[Bugcrowd] OTP challenge triggered')
        expect(ScopesExtractor.logger).to receive(:debug).with(/Following redirect to/)
        expect(ScopesExtractor.logger).to receive(:debug).with('[Bugcrowd] Authentication successful')
        authenticator.authenticate
      end
    end

    context 'when login page fetch fails' do
      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('identity.bugcrowd.com/login'))
          .and_return(double('Response', success?: false, code: 500))
      end

      it 'returns false' do
        expect(authenticator.authenticate).to be false
      end

      it 'logs error message' do
        expect(ScopesExtractor.logger).to receive(:error).with(/Failed to fetch login page/)
        authenticator.authenticate
      end
    end

    context 'when CSRF token extraction fails' do
      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('identity.bugcrowd.com/login'))
          .and_return(double('Response', success?: true, code: 200, headers: {}, body: ''))
      end

      it 'returns false' do
        expect(authenticator.authenticate).to be false
      end

      it 'logs error message' do
        expect(ScopesExtractor.logger).to receive(:error).with('[Bugcrowd] Failed to extract CSRF token')
        authenticator.authenticate
      end
    end

    context 'when initial login fails' do
      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('identity.bugcrowd.com/login'))
          .and_return(login_page_response)
        allow(ScopesExtractor::HTTP).to receive(:post)
          .with(include('identity.bugcrowd.com/login'), any_args)
          .and_return(double('Response', success?: false, code: 401))
      end

      it 'returns false' do
        expect(authenticator.authenticate).to be false
      end

      it 'logs error message' do
        expect(ScopesExtractor.logger).to receive(:error).with(/Login failed: 401/)
        authenticator.authenticate
      end
    end

    context 'when OTP challenge fails' do
      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('identity.bugcrowd.com/login'))
          .and_return(login_page_response)
        allow(ScopesExtractor::HTTP).to receive(:post)
          .with(include('identity.bugcrowd.com/login'), any_args)
          .and_return(login_response)
        allow(ScopesExtractor::HTTP).to receive(:post)
          .with(include('otp-challenge'), any_args)
          .and_return(double('Response', success?: false, code: 401))
      end

      it 'returns false' do
        expect(authenticator.authenticate).to be false
      end

      it 'logs error message' do
        expect(ScopesExtractor.logger).to receive(:error).with(/OTP challenge failed/)
        authenticator.authenticate
      end
    end

    context 'when dashboard verification fails' do
      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('identity.bugcrowd.com/login'))
          .and_return(login_page_response)
        allow(ScopesExtractor::HTTP).to receive(:post)
          .with(include('identity.bugcrowd.com/login'), any_args)
          .and_return(login_response)
        allow(ScopesExtractor::HTTP).to receive(:post)
          .with(include('otp-challenge'), any_args)
          .and_return(otp_response)
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with('https://bugcrowd.com/auth/callback')
          .and_return(redirect_response)
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with('https://bugcrowd.com/dashboard')
          .and_return(double('Response', success?: true, code: 200, body: '<html>Not logged in</html>', headers: {}))
      end

      it 'returns false' do
        expect(authenticator.authenticate).to be false
      end

      it 'logs error message' do
        expect(ScopesExtractor.logger).to receive(:error).with('[Bugcrowd] Authentication verification failed')
        authenticator.authenticate
      end
    end

    context 'when an exception occurs' do
      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('identity.bugcrowd.com/login'))
          .and_raise(StandardError, 'Network error')
      end

      it 'returns false' do
        expect(authenticator.authenticate).to be false
      end

      it 'logs error message' do
        expect(ScopesExtractor.logger).to receive(:error).with(/Authentication error: Network error/)
        authenticator.authenticate
      end
    end

    context 'with redirects' do
      let(:redirect_302_response) do
        double('Response',
               success?: false,
               code: 302,
               headers: { 'Location' => '/dashboard' })
      end

      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('identity.bugcrowd.com/login'))
          .and_return(login_page_response)
        allow(ScopesExtractor::HTTP).to receive(:post)
          .with(include('identity.bugcrowd.com/login'), any_args)
          .and_return(login_response)
        allow(ScopesExtractor::HTTP).to receive(:post)
          .with(include('otp-challenge'), any_args)
          .and_return(otp_response)
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with('https://bugcrowd.com/auth/callback')
          .and_return(redirect_302_response)
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with('https://bugcrowd.com/dashboard')
          .and_return(dashboard_response)
      end

      it 'follows redirects' do
        expect(ScopesExtractor::HTTP).to receive(:get).with('https://bugcrowd.com/dashboard')
        authenticator.authenticate
      end

      it 'handles relative URLs' do
        expect(ScopesExtractor.logger).to receive(:debug).with('[Bugcrowd] Starting authentication flow')
        expect(ScopesExtractor.logger).to receive(:debug).with(/CSRF token extracted/)
        expect(ScopesExtractor.logger).to receive(:debug).with('[Bugcrowd] OTP challenge triggered')
        expect(ScopesExtractor.logger).to receive(:debug).with(/Following redirect to/)
        expect(ScopesExtractor.logger).to receive(:debug).with(%r{Redirect to: https://bugcrowd.com/dashboard})
        expect(ScopesExtractor.logger).to receive(:debug).with('[Bugcrowd] Authentication successful')
        authenticator.authenticate
      end
    end

    context 'with Set-Cookie as array' do
      let(:login_page_response) do
        double('Response',
               success?: true,
               code: 200,
               headers: { 'Set-Cookie' => ['other=value; Path=/', 'csrf-token=array_csrf; Path=/'] },
               body: '<html></html>')
      end

      before do
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with(include('identity.bugcrowd.com/login'))
          .and_return(login_page_response)
        allow(ScopesExtractor::HTTP).to receive(:post)
          .with(include('identity.bugcrowd.com/login'), any_args)
          .and_return(login_response)
        allow(ScopesExtractor::HTTP).to receive(:post)
          .with(include('otp-challenge'), any_args)
          .and_return(otp_response)
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with('https://bugcrowd.com/auth/callback')
          .and_return(redirect_response)
        allow(ScopesExtractor::HTTP).to receive(:get)
          .with('https://bugcrowd.com/dashboard')
          .and_return(dashboard_response)
      end

      it 'extracts CSRF from cookie array' do
        expect(authenticator.authenticate).to be true
      end
    end
  end
end
