# frozen_string_literal: true

require 'sequel'

module SurveyTracker
  module Database
    module Orm
      # Sequel ORM model for the survey_sessions table
      class SurveySession < Sequel::Model(SurveyTracker::Api.db[:survey_sessions])
        plugin :timestamps, update_on_create: true

        one_to_many :behavior_events,
                    class: 'SurveyTracker::Database::Orm::BehaviorEvent',
                    key: :survey_session_id
      end
    end
  end
end
