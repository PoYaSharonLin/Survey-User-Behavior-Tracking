# frozen_string_literal: true

require 'sequel'

module SurveyTracker
  module Database
    module Orm
      # Sequel ORM model for the survey_sessions table
      class SurveySession < Sequel::Model(SurveyTracker::Api.db[:survey_sessions])
        plugin :timestamps, update_on_create: true
      end
    end
  end
end
