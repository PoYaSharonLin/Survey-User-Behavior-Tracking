# frozen_string_literal: true

module SurveyTracker
  module Database
    module Repository
      # Repository for survey_sessions table
      class SurveySessions
        def find_by_user_id(user_id)
          Orm::SurveySession.first(user_id:)
        end

        # Idempotent: returns existing session if user_id already recorded
        def find_or_create(user_id:, original_url: nil, metadata: nil)
          existing = find_by_user_id(user_id)
          return existing if existing

          Orm::SurveySession.create(
            user_id:,
            original_url:,
            metadata:,
            started_at: Time.now.utc
          )
        end

        def update_ended_at(user_id:)
          session = find_by_user_id(user_id)
          return nil unless session

          session.update(ended_at: Time.now.utc)
          session
        end
      end
    end
  end
end
