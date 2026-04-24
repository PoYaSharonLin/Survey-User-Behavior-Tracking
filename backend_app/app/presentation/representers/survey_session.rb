# frozen_string_literal: true

require 'roar/decorator'
require 'roar/json'

module SurveyTracker
  module Representer
    # JSON representer for a SurveySession domain entity.
    # Includes share_url so other apps can use it directly.
    class SurveySession < Roar::Decorator
      include Roar::JSON

      property :id
      property :respondent_id
      property :original_url
      property :started_at
      property :ended_at
      property :metadata

      # Generates the canonical survey URL containing the respondent_id.
      # Other apps can GET /api/survey/session/:respondent_id and read this field.
      property :share_url, exec_context: :decorator

      def share_url
        base_url = ENV['APP_BASE_URL'] || 'http://localhost:8080'
        "#{base_url}/survey?uid=#{represented.respondent_id}"
      end
    end
  end
end
