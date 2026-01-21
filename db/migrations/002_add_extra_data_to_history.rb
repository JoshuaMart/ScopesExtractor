# frozen_string_literal: true

Sequel.migration do
  up do
    add_column :history, :extra_data, String, text: true
  end

  down do
    drop_column :history, :extra_data
  end
end
