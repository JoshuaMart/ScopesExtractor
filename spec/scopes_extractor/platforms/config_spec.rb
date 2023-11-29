# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ScopesExtractor::Config do
  describe '.load' do
    before do
      stub_const('ENV', {
                   'YWH_EMAIL' => 'ywh_email@example.com',
                   'YWH_PWD' => 'ywh_password',
                   'YWH_OTP' => 'ywh_otp',
                   'INTIGRITI_EMAIL' => 'intigriti_email@example.com',
                   'INTIGRITI_PWD' => 'intigriti_password',
                   'INTIGRITI_OTP' => 'intigriti_otp'
                 })
    end

    it 'loads configuration from environment variables' do
      config = described_class.load

      expect(config[:yeswehack][:email]).to eq('ywh_email@example.com')
      expect(config[:yeswehack][:password]).to eq('ywh_password')
      expect(config[:yeswehack][:otp]).to eq('ywh_otp')
      expect(config[:intigriti][:email]).to eq('intigriti_email@example.com')
      expect(config[:intigriti][:password]).to eq('intigriti_password')
      expect(config[:intigriti][:otp]).to eq('intigriti_otp')
    end
  end
end
