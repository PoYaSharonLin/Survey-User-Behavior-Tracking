# frozen_string_literal: true

require 'json'

module SurveyTracker
  module Database
    module Repository
      # Repository for the trajectories table
      class BehaviorEvents
        # Insert a batch of trajectories in a single DB transaction
        def create_batch(survey_session_id:, trajectories:)
          now = Time.now.utc
          rows = trajectories.map do |traj|
            {
              survey_session_id: survey_session_id,
              trajectory_type:   traj[:type],
              events:            traj[:events].to_json,
              created_at:        now,
            }
          end

          SurveyTracker::Api.db[:trajectories].multi_insert(rows)
        end

        def list_by_session(survey_session_id:, limit: 5000)
          Orm::Trajectory
            .where(survey_session_id:)
            .order(:created_at)
            .limit(limit)
            .all
        end
      end
    end
  end
end
