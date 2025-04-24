# frozen_string_literal: true

module ScopesExtractor
  # YesWeHack module handles all interactions with the YesWeHack bug bounty platform
  module YesWeHack
    # API endpoint URLs
    LOGIN_URL = 'https://api.yeswehack.com/login'
    OTP_LOGIN_URL = 'https://api.yeswehack.com/account/totp'

    # Authenticates with YesWeHack using email, password and TOTP
    # @param config [Hash] Configuration containing credentials
    # @return [String, nil] JWT token if authentication is successful, nil otherwise
    def self.authenticate(config)
      response = extract_totp_token(config)
      return response if response[:error]

      extract_jwt(response[:totp], config)
    end

    # Extracts a TOTP token by authenticating with email and password
    # @param config [Hash] Configuration containing email and password
    # @return [String, nil] TOTP token if first authentication step is successful, nil otherwise
    def self.extract_totp_token(config)
      body = { email: config[:email], password: config[:password] }.to_json

      response = HttpClient.post(LOGIN_URL, { body: body })
      return { error: 'Invalid login or password' } unless response&.code == 200

      json = Parser.json_parse(response.body)
      return { error: 'Invalid response' } unless json

      { totp: json['totp_token'] }
    end

    # Extracts a JWT token by authenticating with a TOTP token and OTP code
    # @param totp_token [String] TOTP token from the first authentication step
    # @param config [Hash] Configuration containing the OTP secret
    # @return [String, nil] JWT token if second authentication step is successful, nil otherwise
    def self.extract_jwt(totp_token, config)
      otp_code = ROTP::TOTP.new(config[:otp]).now
      body = { token: totp_token, code: otp_code }.to_json

      response = HttpClient.post(OTP_LOGIN_URL, { body: body })
      return { error: 'Invalid OTP' } unless response.code == 200

      json = Parser.json_parse(response.body)
      return { error: 'Invalid response' } unless json

      { jwt: json['token'] }
    end
  end
end
