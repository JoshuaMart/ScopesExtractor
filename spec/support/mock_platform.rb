# frozen_string_literal: true

# Mock platform class for testing
class MockPlatform
  attr_reader :name

  def initialize(name: 'TestPlatform', programs: [])
    @name = name
    @programs = programs
  end

  def fetch_programs
    @programs
  end

  def valid_access?
    true
  end
end
