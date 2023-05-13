# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'scopes_extractor'
  spec.version       = '0.1.0'
  spec.authors       = ['Joshua MARTINELLE']
  spec.email         = ['contact@jomar.fr']
  spec.summary       = 'BugBounty Scopes Extractor'
  spec.homepage      = 'https://rubygems.org/gems/scopes_extractor'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 2.7.1'

  spec.add_dependency('colorize', '~> 0.8.1')
  spec.add_dependency('dotenv', '~> 2.8', '>= 2.8.1')
  spec.add_dependency('logger', '~> 1.5', '>= 1.5.3')
  spec.add_dependency('mechanize', '~> 2.9', '>= 2.9.1')
  spec.add_dependency('typhoeus', '~> 1.4', '>= 1.4.0')
  spec.add_dependency('rotp', '~> 6.2', '>= 6.2.2')

  spec.files = Dir['lib/**/*.rb']
end