# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  change do
    create_table(:survey_sessions) do
      primary_key :id
      String :user_id, null: false, unique: true
      String :original_url, text: true
      DateTime :started_at, null: false
      DateTime :ended_at
      String :metadata, text: true  # JSON string: referrer, user-agent, extra query params
      DateTime :created_at
      DateTime :updated_at
    end
  end
end
