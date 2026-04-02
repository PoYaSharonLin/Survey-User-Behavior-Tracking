# frozen_string_literal: true

module SurveyTracker
  module Service
    module BehaviorEvents
      # Lists all trajectories for a given user_id's session
      class ListEvents < ApplicationOperation

        def call(user_id:, limit: 5000)
          session_record = Database::Repository::SurveySessions.new.find_by_user_id(user_id)
          return Failure(not_found("No session for user_id: #{user_id}")) unless session_record

          records = Database::Repository::BehaviorEvents.new.list_by_session(
            survey_session_id: session_record.id,
            limit:
          )

          trajectories = records.map do |r|
            Domain::BehaviorEvents::Trajectory.new(
              id:                r.id,
              survey_session_id: r.survey_session_id,
              trajectory_type:   r.trajectory_type,
              events:            r.events,
              created_at:        r.created_at,
            )
          end

          Success(ok(trajectories))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
