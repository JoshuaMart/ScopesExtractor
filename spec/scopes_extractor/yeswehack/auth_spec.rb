# frozen_string_literal: true

require 'spec_helper'

describe ScopesExtractor::YesWeHack do
  describe '.authenticate' do
    let(:config) { { email: 'test@example.com', password: 'password', otp: 'AAAAADAOAAHEK' } }

    context 'when authentication is successful' do
      before do
        WebMock.allow_net_connect!
      end

      it 'returns a JWT token' do
        config = { email: ENV['YWH_EMAIL'], password: ENV['YWH_PWD'], otp: ENV['YWH_OTP'] }

        jwt_token = described_class.authenticate(config)
        expect(jwt_token).to match(/\A[\w-]+\.[\w-]+\.[\w-]+\z/)
      end
    end

    context 'when authentication fails' do
      before do
        stub_request(:post, 'https://api.yeswehack.com/login')
          .to_return(status: 401)
      end

      it 'returns nil' do
        expect(described_class.authenticate(config)).to be_nil
      end
    end
  end
end
