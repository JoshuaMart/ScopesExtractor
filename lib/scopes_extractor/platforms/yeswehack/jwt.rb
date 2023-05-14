# frozen_string_literal: true

class YesWeHack
  # YesWeHack Auth Class
  class Auth
    def self.jwt
      totp_token = extract_totp_token
      return unless totp_token

      response = send_totp(totp_token)
      return unless response

      jwt = JSON.parse(response.body)['token']
      return unless jwt

      jwt
    end

    def self.extract_totp_token
      data = { email: ENV.fetch('YWH_EMAIL', nil), password: ENV.fetch('YWH_PASSWORD', nil) }.to_json
      response = HttpClient.post('https://api.yeswehack.com/login', data)
      return unless response&.code == 200

      JSON.parse(response.body)['totp_token']
    end

    def self.send_totp(totp_token)
      data = { token: totp_token, code: ROTP::TOTP.new(ENV['YWH_OTP']).now }.to_json
      response = HttpClient.post('https://api.yeswehack.com/account/totp', data)
      return unless response.code == 200

      response
    end
  end
end
