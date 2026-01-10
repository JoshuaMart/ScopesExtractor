# frozen_string_literal: true

source 'https://rubygems.org'

ruby '>= 3.4.0'

# Core dependencies
gem 'colorize', '~> 1.1'             # Colored terminal output
gem 'concurrent-ruby', '~> 1.3'      # Parallel execution
gem 'dotenv', '~> 3.1'               # Load environment variables from .env
gem 'dry-struct', '~> 1.8'           # Type-safe models
gem 'dry-types', '~> 1.9'            # Type system
gem 'logger', '~> 1.7'               # Logging
gem 'puma', '~> 7.1'                 # REST API
gem 'rack', '~> 3.2'                 # REST API
gem 'rackup', '~> 2.3'               # REST API
gem 'sequel', '~> 5.100'             # Database ORM
gem 'sinatra', '~> 4.2'              # REST API
gem 'sqlite3', '~> 2.9'              # Database
gem 'thor', '~> 1.5'                 # CLI framework
gem 'typhoeus', '~> 1.5'             # Fast HTTP client with libcurl
gem 'yaml', '~> 0.4'                 # Configuration files

# Development & Testing
group :development, :test do
  gem 'pry', '~> 0.16'                  # Debugging
  gem 'rack-test', '~> 2.1'             # API testing
  gem 'rspec', '~> 3.13'                # Testing framework
  gem 'rubocop', '~> 1.82'              # Code quality
  gem 'rubocop-performance', '~> 1.26'  # Performance cops
  gem 'rubocop-rspec', '~> 3.9'         # RSpec style guide
  gem 'rubocop-sequel', '~> 0.4'        # Sequel style guide
  gem 'simplecov', '~> 0.22'            # Code coverage
  gem 'webmock', '~> 3.24'              # HTTP mocking for tests
end

# Optional: OTP for 2FA
gem 'rotp', '~> 6.3' # TOTP for YesWeHack/Bugcrowd
