# frozen_string_literal: true

Sequel.migration do
  up do
    unless schema(:history).any? { |column, _| column == :extra_data }
      add_column :history, :extra_data, String, text: true
    end
  end

  down do
    drop_column :history, :extra_data if schema(:history).any? { |column, _| column == :extra_data }
  end
end
