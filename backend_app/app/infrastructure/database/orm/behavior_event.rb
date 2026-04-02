# frozen_string_literal: true

require 'sequel'

module SurveyTracker
  module Database
    module Orm
      # Sequel ORM model for the trajectories table
      class Trajectory < Sequel::Model(SurveyTracker::Api.db[:trajectories])
        plugin :timestamps, update_on_create: true

        many_to_one :survey_session,
                    class: 'SurveyTracker::Database::Orm::SurveySession',
                    key: :survey_session_id
      end
    end
  end
end
