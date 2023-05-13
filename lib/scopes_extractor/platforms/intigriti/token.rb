# frozen_string_literal: true

require 'mechanize'

class Intigriti
  # Intigriti Auth Class
  class Auth
    def self.token
      # Use Mechanize otherwise the login flow is a hell with Typhoeus
      mechanize = Mechanize.new

      submit_credentials(mechanize)
      submit_otp(mechanize)
      token = dump_token(mechanize)
      return unless token

      token
    end

    def self.submit_credentials(mechanize)
      login_page = mechanize.get('https://login.intigriti.com/account/login')
      form = login_page.forms.first

      form.field_with(id: 'Input_Email').value = ENV.fetch('INTIGRITI_EMAIL', nil)
      resp = form.submit
      form = resp.forms.first

      form.field_with(id: 'Input_Password').value = ENV.fetch('INTIGRITI_PASSWORD', nil)
      form.submit
    end

    def self.submit_otp(mechanize)
      return if ENV['INTIGRITI_OTP']&.empty?

      totp_page = mechanize.get('https://login.intigriti.com/account/loginwith2fa')
      totp_code = ROTP::TOTP.new(ENV.fetch('INTI_OTP', nil))

      form = totp_page.forms.first
      form.field_with(id: 'Input_TwoFactorAuthentication_VerificationCode').value = totp_code.now
      form.submit
    end

    def self.dump_token(mechanize)
      begin
        token_page = mechanize.get('https://app.intigriti.com/auth/token')
      rescue Mechanize::ResponseCodeError
        return
      end
      return unless token_page&.body

      token_page.body&.undump
    end
  end
end