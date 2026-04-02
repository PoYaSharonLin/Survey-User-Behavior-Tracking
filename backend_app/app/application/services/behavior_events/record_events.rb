# frozen_string_literal: true

module SurveyTracker
  module Service
    module BehaviorEvents
      # Records one or many trajectories for a given user_id's session.
      class RecordEvents < ApplicationOperation

        VALID_TRAJECTORY_TYPES = %w[MM PC HL HV SC SL].freeze

        def call(user_id:, trajectories:)
          return Failure(bad_request('trajectories must be an array')) unless trajectories.is_a?(Array)
          return Failure(bad_request('trajectories array is empty'))   if trajectories.empty?

          session_record = Database::Repository::SurveySessions.new.find_by_user_id(user_id)
          return Failure(not_found("No session for user_id: #{user_id}")) unless session_record

          trajectories.each do |traj|
            unless VALID_TRAJECTORY_TYPES.include?(traj[:type])
              return Failure(bad_request("Invalid trajectory type: #{traj[:type]}"))
            end
            unless traj[:events].is_a?(Array)
              return Failure(bad_request("events must be an array for trajectory type: #{traj[:type]}"))
            end
          end

          Database::Repository::BehaviorEvents.new.create_batch(
            survey_session_id: session_record.id,
            trajectories:
          )

          Success(created("#{trajectories.size} trajectory(s) recorded"))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
