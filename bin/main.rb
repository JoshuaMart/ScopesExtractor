#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../libs/scopes_extractor/'

require 'ipaddr'
require 'uri'
require 'public_suffix'
require 'typhoeus'
require 'dotenv/load'

API_URL = ENV.fetch('API_URL', nil)
API_URLS_PATH = ENV.fetch('API_URLS_PATH', nil)
API_WILDCARDS_PATH = ENV.fetch('API_WILDCARDS_PATH', nil)
API_TOKEN = ENV.fetch('API_TOKEN', nil)
SLACK_WEBHOOK = ENV.fetch('SLACK_WEBHOOK', nil)

def notif(msg)
  return unless SLACK_WEBHOOK

  Typhoeus.post(SLACK_WEBHOOK, headers: { 'Content-Type' => 'application/json' }, body: { text: msg }.to_json)
end

def extract_domain(value)
  if value.match?(/\A\d/)
    begin
      IPAddr.new(value)
      value
    rescue IPAddr::InvalidAddressError
      nil
    end
  else
    host = value.start_with?('http') ? URI.parse(value)&.host : value.sub(/\/.*/, '')
    domain = PublicSuffix.domain(host)

    invalid_chars = [',', '{', '<', '[', '(', ' ', '/']
    if invalid_chars.any? { |char| domain.include?(char) } || !domain.include?('.')
      puts "[-] Non-normalized domain : #{domain}"
      return
    end

    domain
  end
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
        next unless domain

        urls[domain] = [] unless urls.key?(domain)
        urls[domain] << url
      end
    end
  end
end
return unless API_URL && API_URLS_PATH && API_WILDCARDS_PATH && API_TOKEN

p '[+] Send wildcards'

api_url = File.join(API_URL, API_WILDCARDS_PATH)
Typhoeus.post(api_url, headers: { 'Authorization' => API_TOKEN }, body: { domains: wildcards }.to_json)

p '[+] Sleep ...'
sleep(30)

p '[+] Send urls'
urls.each do |domain, urls|
  next if urls.empty?

  body = { domain => urls }.to_json
  api_url = File.join(API_URL, API_URLS_PATH)
  Typhoeus.post(api_url, headers: { 'Authorization' => API_TOKEN }, body: body)
end
