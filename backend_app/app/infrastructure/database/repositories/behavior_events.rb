# frozen_string_literal: true

module SurveyTracker
  module Database
    module Repository
      # Repository for behavior_events table
      class BehaviorEvents
        # Insert a batch of events in a single DB transaction for efficiency
        def create_batch(survey_session_id:, events:)
          now = Time.now.utc
          rows = events.map do |evt|
            {
              survey_session_id:,
              event_type:        evt[:event_type],
              x:                 evt[:x],
              y:                 evt[:y],
              element_selector:  evt[:element_selector],
              text_content:      evt[:text_content],
              timestamp:         evt[:timestamp] ? Time.parse(evt[:timestamp].to_s).utc : now,
              extra:             evt[:extra],
              created_at:        now
            }
          end

          SurveyTracker::Api.db[:behavior_events].multi_insert(rows)
        end

        def list_by_session(survey_session_id:, limit: 5000)
          Orm::BehaviorEvent
            .where(survey_session_id:)
            .order(:timestamp)
            .limit(limit)
            .all
        end
      end
    end
  end
end
