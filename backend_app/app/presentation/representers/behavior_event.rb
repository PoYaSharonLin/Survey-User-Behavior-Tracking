# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'
require 'json'

module SurveyTracker
  module Representer
    # JSON representer for a single Trajectory domain entity
    class Trajectory < Roar::Decorator
      include Roar::JSON

      property :id
      property :survey_session_id
      property :trajectory_type
      # Parse the stored JSON string back to an array for API consumers
      property :events, getter: ->(represented:, **) { JSON.parse(represented.events) rescue [] }
      property :created_at
    end

    # Collection representer for an array of Trajectory entities
    class TrajectoryList
      def self.from_entities(trajectories)
        trajectories.map { |t| Trajectory.new(t).to_hash }
      end
    end
  end
end
