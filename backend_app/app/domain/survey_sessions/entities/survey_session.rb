# frozen_string_literal: true

require 'dry-struct'
require_relative '../../types'

module SurveyTracker
  module Domain
    module SurveySessions
      # Immutable domain entity representing a user's survey session
      class SurveySession < Dry::Struct
        attribute :id,           SurveyTracker::Types::Integer.optional.meta(omittable: true)
        attribute :user_id,      SurveyTracker::Types::String
        attribute :original_url, SurveyTracker::Types::String.optional.meta(omittable: true)
        attribute :started_at,   SurveyTracker::Types::FlexibleDateTime
        attribute :ended_at,     SurveyTracker::Types::FlexibleDateTime.optional.meta(omittable: true)
        attribute :metadata,     SurveyTracker::Types::String.optional.meta(omittable: true)
        attribute :created_at,   SurveyTracker::Types::FlexibleDateTime.optional.meta(omittable: true)
        attribute :updated_at,   SurveyTracker::Types::FlexibleDateTime.optional.meta(omittable: true)
      end
    end
  end
end
