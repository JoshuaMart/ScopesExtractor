# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:ignored_assets) do
      primary_key :id
      String :platform, null: false
      String :program_id, null: false
      String :value, null: false
      String :reason, null: false
      DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP

      index %i[platform program_id value], unique: true
    end
  end
end
