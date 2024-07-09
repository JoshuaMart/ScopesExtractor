#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../libs/scopes_extractor/'

require 'uri'
require 'public_suffix'
require 'typhoeus'
require 'dotenv/load'

API_URL = ENV.fetch('API_URL', nil)
API_URLS_PATH = ENV.fetch('API_URLS_PATH', nil)
API_WILDCARDS_PATH = ENV.fetch('API_URLS_PATH', nil)
API_TOKEN = ENV.fetch('API_PATH', nil)
SLACK_WEBHOOK = ENV.fetch('SLACK_WEBHOOK', nil)

def notif(msg)
  return unless SLACK_WEBHOOK

  Typhoeus.post(SLACK_WEBHOOK, headers: { 'Content-Type' => 'application/json' }, body: { text: msg }.to_json)
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
        wildcards << url
      else
        host = url.start_with?('http') ? URI.parse(url)&.host : url
        domain = PublicSuffix.domain(host)

        urls[domain] = [] unless urls.key?(domain)
        urls[domain] << url
      end
    end
  end
end
return unless API_URL && API_URLS_PATH && API_WILDCARDS_PATH && API_TOKEN

p '[+] Send results'

urls.each do |domain, urls|
  next if urls.empty?

  { domain => urls }.to_json
  api_url = File.join(API_URL, '/urls?new_only=1')
  resp = Typhoeus.post(api_url, headers: { 'Authorization' => API_TOKEN }, body: body)
end

api_url = File.join(API_URL, '/scan?new_only=1')
Typhoeus.post(api_url, headers: { 'Authorization' => 'Bearer API_TOKEN' }, body: { domains: wildcards }.to_json)