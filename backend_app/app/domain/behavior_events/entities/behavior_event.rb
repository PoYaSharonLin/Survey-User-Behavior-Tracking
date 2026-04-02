# frozen_string_literal: true

require 'dry-struct'
require_relative '../../types'

module SurveyTracker
  module Domain
    module BehaviorEvents
      # Immutable domain entity representing a single trajectory
      # (a grouped sequence of raw input events of the same type).
      class Trajectory < Dry::Struct
        attribute :id,                SurveyTracker::Types::Integer.optional.meta(omittable: true)
        attribute :survey_session_id, SurveyTracker::Types::Integer
        attribute :trajectory_type,   SurveyTracker::Types::String   # MM | PC | HL | HV | SC | SL
        attribute :events,            SurveyTracker::Types::String   # JSON text: [[x,y,type,ts,...],...]
        attribute :created_at,        SurveyTracker::Types::FlexibleDateTime.optional.meta(omittable: true)
      end
    end
  end
end
