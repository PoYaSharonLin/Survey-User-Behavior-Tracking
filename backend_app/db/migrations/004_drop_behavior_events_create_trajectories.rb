# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  up do
    drop_table(:behavior_events)

    create_table(:trajectories) do
      primary_key :id
      foreign_key :survey_session_id, :survey_sessions, null: false, on_delete: :cascade

      # Trajectory classification: MM | PC | HL | HV | SC | SL
      String :trajectory_type, null: false

      # Compact event array stored as JSON text.
      # Each inner array: [x, y, event_name, timestamp_ms, ...optional_extras]
      String :events, text: true, null: false

      DateTime :created_at
    end

    add_index :trajectories, %i[survey_session_id created_at]
  end

  down do
    drop_table(:trajectories)
  end
end
