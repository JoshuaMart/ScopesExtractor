#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../libs/scopes_extractor/'

require 'ipaddr'
require 'uri'
require 'public_suffix'
require 'faraday'
require 'dotenv/load'

RECON_URL = ENV.fetch('RECON_URL', nil)
RECON_TOKEN = ENV.fetch('RECON_TOKEN', nil)
RECON_AUTH_TYPE = ENV.fetch('RECON_AUTH_TYPE', nil)

FINGERPRINTER_URL = ENV.fetch('FINGERPRINTER_URL', nil)
RECON_CALLBACK_URL = ENV.fetch('RECON_CALLBACK_URL', nil)
FINGERPRINTER_TOKEN = ENV.fetch('FINGERPRINTER_TOKEN', nil)
FINGERPRINTER_AUTH_TYPE = ENV.fetch('FINGERPRINTER_AUTH_TYPE', nil)

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
    host = if value.start_with?('http')
             URI.parse(value)&.host
           else
             URI.parse("http://#{value}")&.host
           end

    PublicSuffix.domain(host)
  end
rescue IPAddr::InvalidAddressError, URI::InvalidURIError
  p "[-] Extract domain nil for '#{value}'."
  nil
end

def extract_wildcard(value)
  return if value.include?('/')

  domain = value[2..]
  PublicSuffix.domain(domain)
  domain
rescue IPAddr::InvalidAddressError
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
        domain = extract_wildcard(url)
        if domain.nil?
          p "[-] Nil domain for '#{url}'."
          next
        end

        wildcards << domain
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

if RECON_URL && RECON_TOKEN && RECON_AUTH_TYPE
  p '[+] Send wildcards'

  conn = Faraday.new do |faraday|
    faraday.options.timeout = 120  # Timeout en secondes
  end
  
  headers = { 'Content-Type' => 'application/json', 'Authorization' => "#{RECON_AUTH_TYPE} #{RECON_TOKEN}" }
  body = { domains: wildcards }.to_json
  
  response = conn.post(RECON_URL) do |req|
    req.headers = headers
    req.body = body
  end
end

if FINGERPRINTER_URL && FINGERPRINTER_TOKEN && FINGERPRINTER_AUTH_TYPE && RECON_CALLBACK_URL
  p '[+] Send urls'
  urls.each do |domain, domain_urls|
    next if domain_urls.empty?

    headers = { 'Content-Type' => 'application/json', 'Authorization' => "#{FINGERPRINTER_AUTH_TYPE} #{FINGERPRINTER_TOKEN}" }
    body = {
      targets: domain_urls,
      callback_url: RECON_CALLBACK_URL
    }.to_json

    Faraday.post(FINGERPRINTER_URL, body, headers)
  end
end
