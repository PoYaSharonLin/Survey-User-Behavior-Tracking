# frozen_string_literal: true

require 'dry-struct'
require_relative '../../types'

module SurveyTracker
  module Domain
    module BehaviorEvents
      # Immutable domain entity representing a single tracked user behavior event
      class BehaviorEvent < Dry::Struct
        attribute :id,                SurveyTracker::Types::Integer.optional.meta(omittable: true)
        attribute :survey_session_id, SurveyTracker::Types::Integer
        attribute :event_type,        SurveyTracker::Types::String
        attribute :x,                 SurveyTracker::Types::Integer.optional.meta(omittable: true)
        attribute :y,                 SurveyTracker::Types::Integer.optional.meta(omittable: true)
        attribute :element_selector,  SurveyTracker::Types::String.optional.meta(omittable: true)
        attribute :text_content,      SurveyTracker::Types::String.optional.meta(omittable: true)
        attribute :timestamp,         SurveyTracker::Types::DateTime
        attribute :extra,             SurveyTracker::Types::String.optional.meta(omittable: true)
        attribute :created_at,        SurveyTracker::Types::DateTime.optional.meta(omittable: true)
      end
    end
  end
end
