# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:behavior_events) do
      primary_key :id
      foreign_key :survey_session_id, :survey_sessions, null: false, on_delete: :cascade

      # Event classification
      String :event_type, null: false  # mousemove | click | highlight | hover | scroll | slider

      # Pixel-level coordinates
      Integer :x
      Integer :y

      # Element targeting
      String :element_selector  # CSS selector of the interacted element
      String :text_content, text: true  # For highlight events: selected text

      # When the event occurred (client-side timestamp for accuracy)
      DateTime :timestamp, null: false

      # Flexible extra data: scroll offsets, hover durations, slider values, etc.
      String :extra, text: true  # JSON string

      DateTime :created_at
    end

    # Composite index for fast lookup by session + time range
    add_index :behavior_events, %i[survey_session_id timestamp]
  end
end
