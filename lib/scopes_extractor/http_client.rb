# frozen_string_literal: true

# HttpClient Class
class HttpClient
  def self.request_options
    {
      ssl_verifypeer: false,
      ssl_verifyhost: 0
    }
  end

  def self.headers(url, authentication)
    if url.include?('yeswehack')
      { 'Content-Type' => 'application/json', Authorization: "Bearer #{authentication}" }
    elsif url.include?('intigriti')
      { Authorization: "Bearer #{authentication}" }
    elsif url.include?('bugcrowd')
      { 'Cookie' => authentication }
    elsif url.include?('hackerone')
      h1_credz = Base64.urlsafe_encode64("#{ENV.fetch('H1_USERNAME', nil)}:#{ENV.fetch('H1_API_KEY', nil)}")
      { 'Accept' => 'application/json', 'Authorization' => "Basic #{h1_credz}" }
    else
      { 'Content-Type' => 'application/json' }
    end
  end

  def self.get(url, authentication = nil)
    options = request_options
    options[:headers] = headers(url, authentication)

    Typhoeus.get(url, options)
  end

  def self.post(url, data)
    options = request_options
    options[:headers] = { 'Content-Type' => 'application/json' }
    options[:body] = data

    Typhoeus.post(url, options)
  end
end
