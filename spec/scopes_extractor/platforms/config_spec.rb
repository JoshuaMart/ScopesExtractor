# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Config do
  describe '.load' do
    before do
      stub_const('ENV', {
                   'YWH_EMAIL' => 'ywh_email@example.com',
                   'YWH_PWD' => 'ywh_password',
                   'YWH_OTP' => 'ywh_otp',
                   'INTIGRITI_TOKEN' => 'intigriti_token'
                 })
    end

    it 'loads configuration from environment variables' do
      config = described_class.load

      expect(config[:yeswehack][:email]).to eq('ywh_email@example.com')
      expect(config[:yeswehack][:password]).to eq('ywh_password')
      expect(config[:yeswehack][:otp]).to eq('ywh_otp')
      expect(config[:intigriti][:token]).to eq('intigriti_token')
    end
  end
end
