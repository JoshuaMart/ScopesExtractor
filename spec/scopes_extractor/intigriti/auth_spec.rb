# frozen_string_literal: true

require 'spec_helper'

describe ScopesExtractor::Intigriti do
  describe '.authenticate' do
    let(:config) { { email: 'test@example.com', password: 'password', otp: 'AAAAADAOAAHEK' } }

    context 'when authentication is successful' do
      before do
        WebMock.allow_net_connect!
      end

      it 'returns a cookie' do
        config = { email: ENV['INTIGRITI_EMAIL'], password: ENV['INTIGRITI_PWD'], otp: ENV['INTIGRITI_OTP'] }

        cookie = described_class.authenticate(config)
        expect(cookie).to match(/^([\w-]){3035}$/)
      end
    end

    context 'when authentication fails' do
      before do
        stub_request(:get, 'https://login.intigriti.com/account/login')
          .to_return(status: 401)
      end

      it 'returns nil' do
        expect(described_class.authenticate(config)).to be_nil
      end
    end
  end
end
