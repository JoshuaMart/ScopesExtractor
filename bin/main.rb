#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../libs/scopes_extractor/'

require 'ipaddr'
require 'uri'
require 'public_suffix'
require 'faraday'
require 'dotenv/load'

API_URL = ENV.fetch('API_URL', nil)
API_URLS_PATH = ENV.fetch('API_URLS_PATH', nil)
API_WILDCARDS_PATH = ENV.fetch('API_WILDCARDS_PATH', nil)
API_TOKEN = ENV.fetch('API_TOKEN', nil)
SLACK_WEBHOOK = ENV.fetch('SLACK_WEBHOOK', nil)

def notif(msg)
  return unless SLACK_WEBHOOK

  Faraday.post(SLACK_WEBHOOK, { text: msg }.to_json, { 'Content-Type' => 'application/json' })
end

def extract_domain(value)
  if value.match?(/\A((?:\d{1,3}\.){3}(?:\d{1,3})\Z)/)
    IPAddr.new(value)
    value
  else
    host = value.start_with?('http') ? URI.parse(value)&.host : value
    PublicSuffix.domain(host)
  end
rescue IPAddr::InvalidAddressError, URI::InvalidURIError
  p "[-] Extract domain nil for '#{value}'."
  nil
end

wildcards = []
urls = {}

notif('[+] Start Scopes Extractor')

p '[+] Start Scopes Extractor'
extractor = ScopesExtractor::Extract.new
extractor.run

p '[+] Parse results'
file = File.read('extract.json')
json = JSON.parse(file)

json.each_value do |programs|
  programs.each_value do |program|
    scopes = program.dig('scopes', 'in', 'url')
    next unless scopes

    scopes.each do |url|
      if url.start_with?('*.')
        wildcards << url.sub(/\/.*/, '')
      else
        domain = extract_domain(url)
        if domain.nil?
          p "[-] Nil domain for '#{url}'."
          next
        end

        urls[domain] = [] unless urls.key?(domain)
        urls[domain] << url
      end
    end
  end
end
return unless API_URL && API_URLS_PATH && API_WILDCARDS_PATH && API_TOKEN

p '[+] Send wildcards'

api_url = File.join(API_URL, API_WILDCARDS_PATH)
Faraday.post(api_url, { domains: wildcards }.to_json, { 'Authorization' => API_TOKEN })

p '[+] Sleep ...'
sleep(30)

p '[+] Send urls'
urls.each do |domain, urls|
  next if urls.empty?

  api_url = File.join(API_URL, API_URLS_PATH)
  Faraday.post(api_url, { domain => urls }.to_json, { 'Authorization' => API_TOKEN })
end
