# frozen_string_literal: true

module ScopesExtractor
  # Intigriti
  module Intigriti
    LOGIN_URL = 'https://login.intigriti.com/account/login'
    OTP_LOGIN_URL = 'https://login.intigriti.com/account/loginwith2fa'
    AUTH_RESEARCHER_URL = 'https://app.intigriti.com/auth/researcher'
    SIGNIN_OIDC_URL = 'https://app.intigriti.com/signin-oidc'
    SIGNIN_OIDC_RESEARCHER_URL = 'https://app.intigriti.com/signin-oidc-researcher'

    def self.authenticate(config)
      cookies = 'cookies.txt'
      File.delete(cookies) if File.exist?(cookies)

      options = { cookiefile: cookies, cookiejar: cookies }
      csrf = fetch_csrf_token(options)
      perform_login(config, csrf, options)

      set_cookie = oidc_requests(options)

      extract_web_researcher_cookie(set_cookie)
    ensure
      File.delete(cookies) if File.exist?(cookies)
    end

    def self.oidc_requests(options)
      resp = HttpClient.get(AUTH_RESEARCHER_URL, options)
      resp = HttpClient.get(resp.headers['location'], options)

      prepare_oidc_body(resp.body, options)
      HttpClient.post(SIGNIN_OIDC_URL, options)

      resp = HttpClient.get(AUTH_RESEARCHER_URL, options)
      resp = HttpClient.get(resp.headers['location'], options)

      prepare_oidc_body(resp&.body, options)
      resp = HttpClient.post(SIGNIN_OIDC_RESEARCHER_URL, options)

      resp.headers['set-cookie']
    end

    def self.prepare_oidc_body(body, options)
      code = body.match(/code' value='([\w-]+)'/)[1]
      scope = body.match(/scope' value='([\w\s]+)'/)[1].gsub(' ', '+')
      state = body.match(/state' value='([\w-]+)'/)[1]
      session_state = body.match(/session_state' value='([.\w-]+)'/)[1]
      iss = 'https://login.intigriti.com'

      options[:body] = "code=#{code}&scope=#{scope}&state=#{state}&session_state=#{session_state}&iss=#{iss}"
    end

    def self.fetch_csrf_token(options)
      resp = HttpClient.get(LOGIN_URL, options)
      return unless resp&.code == 200 && resp.body

      match = resp.body&.match(/__RequestVerificationToken" type="hidden" value="(?<csrf>[\w-]+)/)
      match[:csrf]
    end

    def self.perform_login(config, csrf, options)
      prepare_login_body(config, csrf, options)
      resp = HttpClient.post(LOGIN_URL, options)
      return false unless resp&.code == 302

      submit_totp(config, csrf, options)
    end

    def self.prepare_login_body(config, csrf, options)
      options[:body] = 'Input.ReturnUrl=&Input.LocalLogin=True&button=login&Input.RememberLogin=false'
      options[:body] += "&Input.Email=#{config[:email]}&Input.Password=#{config[:password]}"
      options[:body] += "&__RequestVerificationToken=#{csrf}"
    end

    def self.submit_totp(config, csrf, options)
      totp_code = ROTP::TOTP.new(config[:otp]).now
      options[:body] = "RememberMe=False&Input.TwoFactorAuthentication.VerificationCode=#{totp_code}"
      options[:body] += "&__RequestVerificationToken=#{csrf}&Input.RememberMachine=false"
      resp = HttpClient.post(OTP_LOGIN_URL, options)

      resp&.code == 302
    end

    def self.extract_web_researcher_cookie(set_cookie_headers)
      set_cookie_headers&.each do |cookie|
        if (match = cookie.match(/__Host-Intigriti.Web.Researcher=(?<cookie>[\w-]+)/))
          return match[:cookie]
        end
      end

      nil
    end
  end
end
