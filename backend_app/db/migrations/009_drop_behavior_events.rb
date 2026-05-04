# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  up do
    drop_table :behavior_events
  end

  down do
    create_table(:behavior_events) do
      primary_key :id
      foreign_key :survey_session_id, :survey_sessions, null: false, on_delete: :cascade
      String   :event_type, null: false
      Integer  :x
      Integer  :y
      String   :element_selector
      String   :text_content, text: true
      DateTime :timestamp, null: false
      String   :extra, text: true
      DateTime :created_at
    end
    add_index :behavior_events, %i[survey_session_id timestamp]
  end
end
