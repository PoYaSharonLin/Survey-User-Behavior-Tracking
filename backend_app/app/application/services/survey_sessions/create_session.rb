# frozen_string_literal: true

module SurveyTracker
  module Service
    module SurveySessions
      # Creates a new survey session for the given user_id, or returns existing one.
      # Idempotent: calling with the same user_id always yields the same session.
      class CreateSession < ApplicationOperation

        def call(user_id:, original_url: nil, metadata: nil)
          return Failure(bad_request('user_id is required')) if user_id.nil? || user_id.strip.empty?

          session_record = Database::Repository::SurveySessions.new.find_or_create(
            user_id:,
            original_url:,
            metadata: metadata&.to_json
          )

          session = Domain::SurveySessions::SurveySession.new(
            id:           session_record.id,
            user_id:      session_record.user_id,
            original_url: session_record.original_url,
            started_at:   session_record.started_at,
            ended_at:     session_record.ended_at,
            metadata:     session_record.metadata,
            created_at:   session_record.created_at,
            updated_at:   session_record.updated_at
          )

          Success(created(session))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
