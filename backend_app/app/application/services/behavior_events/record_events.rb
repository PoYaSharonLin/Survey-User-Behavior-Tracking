# frozen_string_literal: true

require 'dry/monads'

module SurveyTracker
  module Service
    module BehaviorEvents
      # Records one or many behavior events for a given user_id's session.
      # Accepts a batch (array) for efficiency with high-frequency mousemove events.
      class RecordEvents < ApplicationOperation
        include Dry::Monads[:result]

        VALID_EVENT_TYPES = %w[mousemove click highlight hover scroll slider].freeze

        def call(user_id:, events:)
          return Failure(bad_request('events must be an array')) unless events.is_a?(Array)
          return Failure(bad_request('events array is empty')) if events.empty?

          session_record = Database::Repository::SurveySessions.new.find_by_user_id(user_id)
          return Failure(not_found("No session for user_id: #{user_id}")) unless session_record

          # Validate and normalise event types
          events.each do |evt|
            unless VALID_EVENT_TYPES.include?(evt[:event_type])
              return Failure(bad_request("Invalid event_type: #{evt[:event_type]}"))
            end
          end

          Database::Repository::BehaviorEvents.new.create_batch(
            survey_session_id: session_record.id,
            events:
          )

          Success(created("#{events.size} event(s) recorded"))
        rescue StandardError => e
          Failure(internal_error(e.message))
        end
      end
    end
  end
end
