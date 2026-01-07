# frozen_string_literal: true

module ScopesExtractor
  module Platforms
    class Base
      def initialize(config)
        @config = config
        @client = HttpClient.new
      end

      def name
        raise NotImplementedError, "#{self.class} must implement #name"
      end

      def fetch_programs
        raise NotImplementedError, "#{self.class} must implement #fetch_programs"
      end
    end
  end
end
