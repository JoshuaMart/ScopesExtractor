# frozen_string_literal: true

module ScopesExtractor
  # Parser
  module Parser
    def self.json_parse(data)
      JSON.parse(data)
    rescue JSON::ParserError
      Utilities.log_warn("JSON parsing error : #{data}")
      nil
    end
  end
end
