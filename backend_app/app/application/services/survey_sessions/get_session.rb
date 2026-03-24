# frozen_string_literal: true

module SurveyTracker
  module Service
    module SurveySessions
      # Retrieves an existing survey session by user_id
      class GetSession < ApplicationOperation

        def call(user_id:)
          record = Database::Repository::SurveySessions.new.find_by_user_id(user_id)
          return Failure(not_found("No session found for user_id: #{user_id}")) unless record

          session = Domain::SurveySessions::SurveySession.new(
            id:           record.id,
            user_id:      record.user_id,
            original_url: record.original_url,
            started_at:   record.started_at,
            ended_at:     record.ended_at,
            metadata:     record.metadata,
            created_at:   record.created_at,
            updated_at:   record.updated_at
          )

          Success(ok(session))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
