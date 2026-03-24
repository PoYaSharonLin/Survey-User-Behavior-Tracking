# frozen_string_literal: true

module SurveyTracker
  module Test
    # Shared test helpers for specs
    module Helpers
      include Rack::Test::Methods

      def app
        SurveyTracker::Api
      end

      # Helper to clear all tables (useful for manual cleanup if needed)
      def clear_database
        SurveyTracker::Api.db.tables.each do |table|
          SurveyTracker::Api.db[table].delete
        end
      end

      # Helper to parse JSON responses
      def json_response
        JSON.parse(last_response.body, symbolize_names: true)
      end
    end
  end
end

# Inject helpers into Minitest::Spec
class Minitest::Spec
  include SurveyTracker::Test::Helpers
end
