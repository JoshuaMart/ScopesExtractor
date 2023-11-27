# frozen_string_literal: true

module ScopesExtractor
  # Intigriti
  module Intigriti
    LOGIN_URL = 'https://login.intigriti.com/account/login'
    OTP_LOGIN_URL = 'https://login.intigriti.com/account/loginwith2fa'
    DASHBOARD_URL = 'https://app.intigriti.com/auth/dashboard'
    AUTH_RESEARCHER_URL = 'https://app.intigriti.com/auth/researcher'
    SIGNIN_OIDC_URL = 'https://app.intigriti.com/signin-oidc'
    SIGNIN_OIDC_RESEARCHER_URL = 'https://app.intigriti.com/signin-oidc-researcher'

    private_class_method :fetch_csrf_token, :perform_login, :perform_additional_requests,
                         :extract_web_researcher_cookie

    def self.authenticate(config)
      cookies = 'cookies.txt'
      File.delete(cookies) if File.exist?(cookies)

      options = { cookiefile: cookies, cookiejar: cookies }
      csrf = fetch_csrf_token(options)
      return unless csrf && perform_login(config, csrf, options)

      perform_additional_requests(options)

      extract_web_researcher_cookie(options)
    ensure
      File.delete(cookies) if File.exist?(cookies)
    end

    def self.fetch_csrf_token(options)
      resp = HttpClient.get(LOGIN_URL, options)
      return unless resp&.code == 200 && resp.body

      match = resp.body&.match(/__RequestVerificationToken" type="hidden" value="(?<csrf>[\w-]+)/)
      match[:csrf]
    end

    def self.perform_login(config, csrf, options)
      prepare_login_body(config, csrf, options)
      resp = Typhoeus.post(LOGIN_URL, options)
      return false unless resp&.code == 302

      submit_totp(config, csrf, options)
    end

    def self.perform_additional_requests(options)
      [
        DASHBOARD_URL, SIGNIN_OIDC_URL,
        AUTH_RESEARCHER_URL, SIGNIN_OIDC_RESEARCHER_URL
      ].each do |url|
        break unless make_request(url, options)
      end
    end

    def self.extract_web_researcher_cookie(options)
      options[:body] = nil
      resp = HttpClient.get(AUTH_RESEARCHER_URL, options)
      return unless resp&.code == 302

      location = resp.headers['location']
      resp = HttpClient.get(location, options)
      return unless resp&.code == 200 && resp.body

      extract_cookie_from_response(resp.headers['set-cookie'])
    end

    def self.prepare_login_body(config, csrf, options)
      options[:body] = 'Input.ReturnUrl=&Input.LocalLogin=True&button=login&Input.RememberLogin=false'
      options[:body] += "&Input.Email=#{config['INTIGRITI_EMAIL']}&Input.Password=#{config['INTIGRITI_PWD']}"
      options[:body] += "&__RequestVerificationToken=#{csrf}"
    end

    def self.submit_totp(config, csrf, options)
      totp_code = ROTP::TOTP.new(config['INTIGRITI_OTP']).now
      options[:body] = "RememberMe=False&Input.TwoFactorAuthentication.VerificationCode=#{totp_code}"
      options[:body] += "&__RequestVerificationToken=#{csrf}&Input.RememberMachine=false"
      resp = HttpClient.post(LOGIN_URL, options)

      resp&.code == 302
    end

    def self.make_request(url, options)
      options[:body] = nil
      resp = HttpClient.get(url, options)

      resp&.code == 302
    end

    def self.extract_cookie_from_response(set_cookie_headers)
      set_cookie_headers&.each do |cookie|
        if (match = cookie.match(/__Host-Intigriti.Web.Researcher=(?<cookie>[\w-]+)/))
          return match[:cookie]
        end
      end

      nil
    end
  end
end
