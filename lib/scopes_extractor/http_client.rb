# frozen_string_literal: true

# HttpClient Class
class HttpClient
  @request_options = {
    ssl_verifypeer: false,
    ssl_verifyhost: 0
  }

  def self.headers(url, authentication)
    case
    when url.include?('yeswehack')
      { 'Content-Type' => 'application/json', Authorization: "Bearer #{authentication}" }
    when url.include?('intigriti')
      { Authorization: "Bearer #{authentication}" }
    when url.include?('bugcrowd')
      { 'Cookie' => authentication }
    when url.include?('hackerone')
      @request_options[:userpwd] = "#{ENV.fetch('H1_USERNAME', nil)}:#{ENV.fetch('H1_API_KEY', nil)}"
      { 'Accept' => 'application/json' }
    else
      { 'Content-Type' => 'application/json' }
    end
  end

  def self.get(url, authentication = nil)
    @request_options[:headers] = headers(url, authentication)

    Typhoeus.get(url, @request_options)
  end

  def self.post(url, data)
    @request_options[:headers] = { 'Content-Type' => 'application/json' }
    @request_options[:body] = data

    Typhoeus.post(url, @request_options)
  end
end