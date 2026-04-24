# frozen_string_literal: true

module SurveyTracker
  module Database
    module Repository
      # Repository for survey_sessions table
      class SurveySessions
        def find_by_respondent_id(respondent_id)
          Orm::SurveySession.first(respondent_id:)
        end

        # Idempotent: returns existing session if respondent_id already recorded
        def find_or_create(respondent_id:, original_url: nil, metadata: nil)
          existing = find_by_respondent_id(respondent_id)
          return existing if existing

          Orm::SurveySession.create(
            respondent_id:,
            original_url:,
            metadata:,
            started_at: Time.now.utc
          )
        end

        def update_ended_at(respondent_id:)
          session = find_by_respondent_id(respondent_id)
          return nil unless session

          session.update(ended_at: Time.now.utc)
          session
        end

        def update_s3_key(respondent_id:, s3_key:)
          session = find_by_respondent_id(respondent_id)
          return nil unless session

          session.update(s3_key:)
          session
        end
      end
    end
  end
end
