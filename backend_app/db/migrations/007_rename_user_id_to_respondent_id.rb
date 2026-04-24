# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  up do
    rename_column :survey_sessions, :user_id, :respondent_id
  end

  down do
    rename_column :survey_sessions, :respondent_id, :user_id
  end
end
