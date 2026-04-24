# frozen_string_literal: true

require 'json'
require 'dry/monads'

module SurveyTracker
  module Routes
    # Survey session routes:
    #   POST /api/survey/session                 → create or resume a session
    #   GET  /api/survey/session/:respondent_id  → get session details + share_url
    class Survey < Roda
      include Dry::Monads[:result]

      plugin :all_verbs
      plugin :request_headers

      route do |r|
        r.on 'session' do
          response['Content-Type'] = 'application/json'

          r.on String do |respondent_id|
            # GET /api/survey/session/:respondent_id
            r.get do
              case Service::SurveySessions::GetSession.new.call(respondent_id:)
              in Success(api_result)
                response.status = api_result.http_status_code
                { success: true, data: Representer::SurveySession.new(api_result.message).to_hash }.to_json
              in Failure(api_result)
                response.status = api_result.http_status_code
                api_result.to_json
              end
            end
          end

          # POST /api/survey/session
          r.post do
            body = JSON.parse(r.body.read, symbolize_names: true)
            respondent_id = body[:respondent_id]
            original_url  = body[:original_url]
            metadata      = body[:metadata]

            case Service::SurveySessions::CreateSession.new.call(
              respondent_id:, original_url:, metadata:
            )
            in Success(api_result)
              response.status = api_result.http_status_code
              { success: true, data: Representer::SurveySession.new(api_result.message).to_hash }.to_json
            in Failure(api_result)
              response.status = api_result.http_status_code
              api_result.to_json
            end
          rescue JSON::ParserError => e
            response.status = 400
            { error: 'Invalid JSON', details: e.message }.to_json
          end
        end
      end
    end
  end
end
