# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:programs) do
      primary_key :id # Auto-increment Integer
      String :platform, null: false
      String :slug, null: false # Platform-specific identifier (handle/slug)
      String :name, null: false
      TrueClass :bounty, default: true
      DateTime :last_updated, default: Sequel::CURRENT_TIMESTAMP

      index %i[platform slug], unique: true
    end

    create_table(:scopes) do
      primary_key :id
      foreign_key :program_id, :programs, type: Integer, on_delete: :cascade
      String :value, null: false
      String :type, null: false # web, mobile, api, other
      TrueClass :is_in_scope, default: true
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index %i[program_id value], unique: true
    end

    create_table(:history) do
      primary_key :id
      foreign_key :program_id, :programs, type: Integer, on_delete: :cascade
      String :event_type, null: false # add_program, add_scope, remove_scope
      String :details
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
    end
  end
end
