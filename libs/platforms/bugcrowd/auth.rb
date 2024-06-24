# frozen_string_literal: true

module ScopesExtractor
  # Bugcrowd
  module Bugcrowd
    LOGIN_URL = 'https://identity.bugcrowd.com/login'

    def self.authenticate(config)
      url = LOGIN_URL + '?user_hint=researcher&returnTo=/dashboard'
      resp = HttpClient.get(url)
      return unless resp&.status == 307

      csrf = extract_csrf(resp)

      location = resp&.headers['location']
      resp = follow_redirects(HttpClient.get(location), 302)
      return unless resp&.status == 200

      challenge = extract_challenge(resp)
      return unless challenge && csrf

      redirect_to = login(config, challenge, csrf)
      return unless redirect_to

      resp = follow_redirects(HttpClient.get(redirect_to), 302, 303, 307)
      return unless resp

      location = resp&.headers['location']
      location == '/dashboard'
    end

    def self.login(config, challenge, csrf)
      options = { 
        headers: { 'X-Csrf-Token' => csrf, 'Origin' => 'https://identity.bugcrowd.com' },
        body: prepare_body(config, challenge)
      }

      resp = HttpClient.post(LOGIN_URL, options)
      return unless resp&.status == 200

      body = Parser.json_parse(resp.body)
      redirect_to = body['redirect_to']
    end

    def self.prepare_body(config, challenge)
      "username=#{CGI::escape(config[:email])}&password=#{CGI::escape(config[:password])}&login_challenge=#{challenge}&user_type=RESEARCHER"
    end

    def self.extract_challenge(resp)
      match = resp.body&.match(/loginChallenge": "(?<challenge>[=\w-]+)/)
      return unless match

      match[:challenge]
    end

    def self.extract_csrf(resp)
      match = resp&.headers['set-cookie']&.match(/csrf-token=(?<csrf>[\w+\/]+)/)
      return unless match

      match[:csrf]
    end

    def self.follow_redirects(response, *expected_statuses)
      while expected_statuses.include?(response&.status)
        location = response&.headers['location']
        return unless location
        return response if location == '/dashboard'

        response = HttpClient.get(location)
      end
      response
    end
  end
end
