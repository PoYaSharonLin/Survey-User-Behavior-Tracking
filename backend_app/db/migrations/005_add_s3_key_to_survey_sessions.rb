# frozen_string_literal: true

require 'sequel'

Sequel.migration do
  up do
    add_column :survey_sessions, :s3_key, String
  end

  down do
    drop_column :survey_sessions, :s3_key
  end
end
