# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module SurveyTracker
  module Representer
    # JSON representer for a single BehaviorEvent domain entity
    class BehaviorEvent < Roar::Decorator
      include Roar::JSON

      property :id
      property :survey_session_id
      property :event_type
      property :x
      property :y
      property :element_selector
      property :text_content
      property :timestamp
      property :extra
      property :created_at
    end

    # Collection representer that serialises an array of BehaviorEvent entities
    class BehaviorEventsList
      def self.from_entities(events)
        events.map { |e| BehaviorEvent.new(e).to_hash }
      end
    end
  end
end
