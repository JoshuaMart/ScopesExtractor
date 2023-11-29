# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Extract do
  describe '#run' do
    let(:fake_config) do
      {
        yeswehack: {
          email: 'fake_email@example.com',
          password: 'fake_password',
          otp: 'fake_otp'
        },
        intigriti: {
          email: 'fake_email@example.com',
          password: 'fake_password',
          otp: 'fake_otp'
        }
      }
    end

    let(:jwt) { 'fake_jwt_token' }
    let(:cookie) { 'fake_cookie' }
    let(:yeswehack_config) { { headers: { 'Content-Type' => 'application/json', Authorization: "Bearer #{jwt}" } } }
    let(:intigriti_config) { { headers: { 'Cookie' => "__Host-Intigriti.Web.Researcher=#{cookie}" } } }

    before do
      allow(ScopesExtractor::Config).to receive(:load).and_return(fake_config)
      allow(ScopesExtractor::YesWeHack).to receive(:authenticate).and_return(jwt)
      allow(ScopesExtractor::Intigriti).to receive(:authenticate).and_return(cookie)
      allow(ScopesExtractor::YesWeHack::Programs).to receive(:sync)
      allow(File).to receive(:open).with('extract.json', 'w')

      stub_request(:get, 'https://app.intigriti.com/api/core/researcher/programs')
        .with(headers: { 'Cookie' => '__Host-Intigriti.Web.Researcher=fake_cookie' })
        .to_return(status: 200, body: '{}', headers: {})
    end

    it 'runs extraction process for YesWeHack and Intigriti' do
      extractor = ScopesExtractor::Extract.new
      extractor.run

      expect(ScopesExtractor::YesWeHack).to have_received(:authenticate).with(extractor.config[:yeswehack])
      expect(ScopesExtractor::Intigriti).to have_received(:authenticate).with(extractor.config[:intigriti])
      expect(ScopesExtractor::YesWeHack::Programs).to have_received(:sync)
      expect(File).to have_received(:open).with('extract.json', 'w')
    end

    context 'when authentication fails' do
      before do
        allow(ScopesExtractor::YesWeHack).to receive(:authenticate).and_return(nil)
        allow(ScopesExtractor::Utilities).to receive(:log_warn)
      end

      it 'logs a warning for failed authentication' do
        extractor = ScopesExtractor::Extract.new
        extractor.run
        expect(ScopesExtractor::Utilities).to have_received(:log_warn).with('YesWeHack - Authentication Failed')
      end
    end
  end
end
