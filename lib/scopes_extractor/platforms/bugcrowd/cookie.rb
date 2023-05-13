# frozen_string_literal: true

require 'mechanize'

class Bugcrowd
  # Bugcrowd Auth Class
  class Auth
    def self.cookie
      # Use Mechanize otherwise the login flow is a hell with Typhoeus
      mechanize = Mechanize.new

      submit_credentials(mechanize)
      cookie = dump_cookie(mechanize)
      return unless cookie

      cookie
    end

    def self.submit_credentials(mechanize)
      login_page = mechanize.get('https://bugcrowd.com/user/sign_in')
      form = login_page.forms.first

      form.field_with(id: 'user_email').value = ENV.fetch('BUGCROWD_EMAIL', nil)
      form.field_with(id: 'user_password').value = ENV.fetch('BUGCROWD_PASSWORD', nil)
      form.submit
    end

    def self.dump_cookie(mechanize)
      begin
        page = mechanize.get('https://bugcrowd.com/dashboard')
      rescue Mechanize::ResponseCodeError
        return
      end
      return unless page

      set_cookie = page.header['Set-Cookie']
      match = /_crowdcontrol_session=[\w-]+/.match(set_cookie)

      match[0]
    end
  end
end