# frozen_string_literal: true

module SurveyTracker
  module Service
    module BehaviorEvents
      # Lists all behavior events for a given user_id's session
      class ListEvents < ApplicationOperation

        def call(user_id:, limit: 5000)
          session_record = Database::Repository::SurveySessions.new.find_by_user_id(user_id)
          return Failure(not_found("No session for user_id: #{user_id}")) unless session_record

          records = Database::Repository::BehaviorEvents.new.list_by_session(
            survey_session_id: session_record.id,
            limit:
          )

          events = records.map do |r|
            Domain::BehaviorEvents::BehaviorEvent.new(
              id:               r.id,
              survey_session_id: r.survey_session_id,
              event_type:       r.event_type,
              x:                r.x,
              y:                r.y,
              element_selector: r.element_selector,
              text_content:     r.text_content,
              timestamp:        r.timestamp,
              extra:            r.extra,
              created_at:       r.created_at
            )
          end

          Success(ok(events))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
