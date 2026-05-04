# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  up do
    add_column :survey_sessions, :status, String, default: 'in_progress'

    # Backfill sessions that already have an s3_key — they are completed.
    DB.run("UPDATE survey_sessions SET status = 'completed' WHERE s3_key IS NOT NULL")
  end

  down do
    drop_column :survey_sessions, :status
  end
end
