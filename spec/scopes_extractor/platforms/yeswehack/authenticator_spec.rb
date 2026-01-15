# frozen_string_literal: true

require 'spec_helper'
require 'webmock/rspec'

RSpec.describe ScopesExtractor::Platforms::YesWeHack::Authenticator do
  let(:email) { 'test@example.com' }
  let(:password) { 'password123' }
  let(:otp_secret) { 'BASE32SECRET3232' }
  let(:authenticator) { described_class.new(email: email, password: password, otp_secret: otp_secret) }

  describe '#initialize' do
    it 'sets email' do
      expect(authenticator.email).to eq(email)
    end

    it 'starts unauthenticated' do
      expect(authenticator.authenticated?).to be false
    end

    it 'has no token initially' do
      expect(authenticator.token).to be_nil
    end
  end

  describe '#authenticate' do
    let(:totp_token) { 'temp_totp_token_123' }
    let(:final_token) { 'final_auth_token_456' }
    let(:otp_code) { '123456' }

    before do
      # Mock ROTP to return predictable OTP code
      allow(ROTP::TOTP).to receive(:new).with(otp_secret).and_return(
        instance_double(ROTP::TOTP, now: otp_code)
      )

      # Mock login request
      stub_request(:post, 'https://api.yeswehack.com/login')
        .with(
          body: { email: email, password: password }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
        .to_return(
          status: 200,
          body: { totp_token: totp_token }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      # Mock TOTP challenge request
      stub_request(:post, 'https://api.yeswehack.com/account/totp')
        .with(
          body: { token: totp_token, code: otp_code }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
        .to_return(
          status: 200,
          body: { token: final_token }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'performs full authentication flow' do
      token = authenticator.authenticate
      expect(token).to eq(final_token)
    end

    it 'sets authenticated to true' do
      authenticator.authenticate
      expect(authenticator.authenticated?).to be true
    end

    it 'stores the token' do
      authenticator.authenticate
      expect(authenticator.token).to eq(final_token)
    end

    it 'logs debug messages' do
      expect(ScopesExtractor.logger).to receive(:debug).with(/Starting authentication/)
      expect(ScopesExtractor.logger).to receive(:debug).with(/Authentication successful/)
      allow(ScopesExtractor.logger).to receive(:debug) # Allow other debug logs (HTTP)
      authenticator.authenticate
    end

    context 'when login fails' do
      before do
        stub_request(:post, 'https://api.yeswehack.com/login')
          .to_return(status: 401, body: 'Unauthorized')
      end

      it 'raises an error' do
        expect { authenticator.authenticate }.to raise_error(/Login failed: 401/)
      end
    end

    context 'when TOTP challenge fails' do
      before do
        stub_request(:post, 'https://api.yeswehack.com/account/totp')
          .to_return(status: 403, body: 'Invalid OTP')
      end

      it 'raises an error' do
        expect { authenticator.authenticate }.to raise_error(/TOTP challenge failed: 403/)
      end
    end

    context 'when login returns direct token (no TOTP)' do
      before do
        stub_request(:post, 'https://api.yeswehack.com/login')
          .to_return(
            status: 200,
            body: { token: final_token }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )

        # Should not call TOTP endpoint
        stub_request(:post, 'https://api.yeswehack.com/account/totp')
          .to_return(status: 200, body: { token: final_token }.to_json)
      end

      it 'uses the direct token for TOTP challenge' do
        authenticator.authenticate
        expect(a_request(:post, 'https://api.yeswehack.com/account/totp')).to have_been_made.once
      end
    end
  end
end
