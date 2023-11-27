#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../libs/scopes_extractor/'

extractor = ScopesExtractor::Extract.new
extractor.run
