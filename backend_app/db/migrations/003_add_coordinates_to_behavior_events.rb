# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    alter_table(:behavior_events) do
      add_column :x_enter, Integer
      add_column :y_enter, Integer
      add_column :x_exit,  Integer
      add_column :y_exit,  Integer
    end
  end
end
