# frozen_string_literal: true

require 'json'

module SurveyTracker
  module Database
    module Repository
      # Repository for the behavior_events table
      class BehaviorEvents
        # Insert a batch of events — one row per event, all in a single multi-insert.
        def create_batch(survey_session_id:, events:)
          now = Time.now.utc
          rows = events.map do |evt|
            {
              survey_session_id: survey_session_id,
              event:             evt.to_json,
              created_at:        now
            }
          end
          SurveyTracker::Api.db[:behavior_events].multi_insert(rows)
        end

        def list_by_session(survey_session_id:, limit: 5000)
          Orm::BehaviorEvent
            .where(survey_session_id:)
            .order(:created_at, :id)
            .limit(limit)
            .all
        end
      end
    end
  end
end
