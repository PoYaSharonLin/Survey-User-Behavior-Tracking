# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  up do
    rename_table :trajectories, :behavior_events
    rename_column :behavior_events, :events, :event
    drop_column :behavior_events, :trajectory_type
  end

  down do
    add_column :behavior_events, :trajectory_type, String
    rename_column :behavior_events, :event, :events
    rename_table :behavior_events, :trajectories
  end
end
