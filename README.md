# EasyManager

> Simple ruby script/library to extract bugbounty scopes

**Available platforms :**
* YesWeHack
* Intigriti
* Hackerone
* Bugcrowd

## Installation

In your Gemfile
```ruby
gem 'scopes_extractor', '~> 0.2.0'
```

Or
```bash
gem install scopes_extractor
```

## Usage example
Fill credentials in a file as defined in the .env.example file
```
mv .env.example .env
```

As library :
```ruby
require 'scopes_extractor'

options = {
  yeswehack: true,
  intigriti: true,
  hackerone: true,
  bugcrowd: true,
  skip_vdp: true,
  credz_file: '.env'
}

extractor = ScopesExtractor.new(options)
results = extractor.extract

p '----'
puts results
```

As script :

```
ruby scopes_extractor.rb --all --skip-vdp --credz-file .env
```
