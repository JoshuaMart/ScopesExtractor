# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:programs) do
      primary_key :id
      String :platform, null: false
      String :slug, null: false
      String :name, null: false
      TrueClass :bounty, default: true
      DateTime :last_updated, default: Sequel::CURRENT_TIMESTAMP

      index %i[platform slug], unique: true
    end

    create_table(:scopes) do
      primary_key :id
      foreign_key :program_id, :programs, type: Integer, on_delete: :cascade, null: false
      String :value, null: false
      String :type, null: false
      TrueClass :is_in_scope, default: true
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index :program_id
      index :value
      index :type
    end

    create_table(:history) do
      primary_key :id
      foreign_key :program_id, :programs, type: Integer, on_delete: :set_null
      String :platform_name
      String :program_name
      String :event_type, null: false
      String :details, text: true
      String :scope_type
      String :category
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index :created_at
      index :platform_name
      index :event_type
    end

    create_table(:ignored_assets) do
      primary_key :id
      String :platform, null: false
      String :program_slug, null: false
      String :value, null: false
      String :reason, text: true
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index %i[platform program_slug value], unique: true
    end
  end
end
