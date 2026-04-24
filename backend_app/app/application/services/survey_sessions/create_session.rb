# frozen_string_literal: true

module SurveyTracker
  module Service
    module SurveySessions
      # Creates a new survey session for the given respondent_id, or returns existing one.
      # Idempotent: calling with the same respondent_id always yields the same session.
      class CreateSession < ApplicationOperation

        def call(respondent_id:, original_url: nil, metadata: nil)
          return Failure(bad_request('respondent_id is required')) if respondent_id.nil? || respondent_id.strip.empty?

          session_record = Database::Repository::SurveySessions.new.find_or_create(
            respondent_id:,
            original_url:,
            metadata: metadata&.to_json
          )

          session = Domain::SurveySessions::SurveySession.new(
            id:             session_record.id,
            respondent_id:  session_record.respondent_id,
            original_url:   session_record.original_url,
            started_at:   session_record.started_at,
            ended_at:     session_record.ended_at,
            metadata:     session_record.metadata,
            created_at:   session_record.created_at,
            updated_at:   session_record.updated_at
          )

          # If metadata is present (submission), upload behavioral data to S3
          if metadata
            begin
              repo   = Database::Repository::BehaviorEvents.new
              events = repo.list_by_session(survey_session_id: session.id)
              Infrastructure::S3Service.new.upload_session_data(respondent_id, events)
            rescue StandardError => e
              # Log but don't fail the session creation/update
              puts "[S3 Export Failed] #{e.message}"
            end
          end

          Success(created(session))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
