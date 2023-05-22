# frozen_string_literal: true

require 'optparse'

require_relative 'lib/scopes_extractor'

options = {}

optparse = OptionParser.new do |opts|
  opts.banner = 'Usage: scopes_extractor.rb [options]'

  opts.on('--yeswehack', 'Extract YesWeHack scopes') do
    options[:yeswehack] = true
  end

  opts.on('--hackerone', 'Extract Hackerone scopes') do
    options[:hackerone] = true
  end

  opts.on('--intigriti', 'Extract Intigriti scopes') do
    options[:intigriti] = true
  end

  opts.on('--bugcrowd', 'Extract Bugcrowd scopes') do
    options[:bugcrowd] = true
  end

  opts.on('--all', 'Extract scopes for all platforms') do
    options[:yeswehack] = true
    options[:hackerone] = true
    options[:intigriti] = true
    options[:bugcrowd] = true
  end

  opts.on('--skip-vdp', 'Skip VDP Programs') do
    options[:skip_vdp] = true
  end

  opts.on('--credz-file file',
          'File containing the platform identifiers for the extraction of scopes for private programs') do |v|
    options[:credz_file] = v
  end
end

begin
  optparse.parse!
rescue OptionParser::InvalidOption
  puts 'See scopes_extractor.rb --help'
  return
end

extractor = ScopesExtractor.new(options)
results = extractor.extract

puts results
