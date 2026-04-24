# frozen_string_literal: true

require 'dry-struct'
require_relative '../../types'

module SurveyTracker
  module Domain
    module BehaviorEvents
      # Immutable domain entity representing a single recorded behavior event.
      class BehaviorEvent < Dry::Struct
        attribute :id,                SurveyTracker::Types::Integer.optional.meta(omittable: true)
        attribute :survey_session_id, SurveyTracker::Types::Integer
        attribute :event,             SurveyTracker::Types::String   # JSON text: { type, x, y, ts, ... }
        attribute :created_at,        SurveyTracker::Types::FlexibleDateTime.optional.meta(omittable: true)
      end
    end
  end
end
