# frozen_string_literal: true

module ScopesExtractor
  # YesWeHack
  module YesWeHack
    LOGIN_URL = 'https://api.yeswehack.com/login'
    OTP_LOGIN_URL = 'https://api.yeswehack.com/account/totp'

    def self.authenticate(config)
      totp_token = extract_totp_token(config)
      return unless totp_token

      extract_jwt(totp_token, config)
    end

    def self.extract_totp_token(config)
      body = { email: config[:email], password: config[:password] }.to_json

      response = HttpClient.post(LOGIN_URL, { body: body })
      return unless response&.status == 200

      json = Parser.json_parse(response.body)
      return unless json

      json['totp_token']
    end

    def self.extract_jwt(totp_token, config)
      otp_code = ROTP::TOTP.new(config[:otp]).now
      body = { token: totp_token, code: otp_code }.to_json

      response = HttpClient.post(OTP_LOGIN_URL, { body: body })
      return unless response.status == 200

      json = Parser.json_parse(response.body)
      return unless json

      json['token']
    end
  end
end
