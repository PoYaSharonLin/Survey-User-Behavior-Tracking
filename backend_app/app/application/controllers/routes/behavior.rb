# frozen_string_literal: true

require 'json'
require 'dry/monads'

module SurveyTracker
  module Routes
    # Behavior event routes:
    #   POST /api/behavior/:user_id/events → record one or many events (batch)
    #   GET  /api/behavior/:user_id/events → list all events for this session
    class Behavior < Roda
      include Dry::Monads[:result]

      plugin :all_verbs
      plugin :request_headers

      route do |r|
        response['Content-Type'] = 'application/json'

        r.on String do |user_id|
          r.on 'events' do
            # POST /api/behavior/:user_id/events
            # Body: { "events": [ { event_type, x, y, element_selector, text_content, timestamp, extra }, ... ] }
            r.post do
              body   = JSON.parse(r.body.read, symbolize_names: true)
              events = body[:events]

              unless events.is_a?(Array)
                response.status = 400
                next({ error: 'events must be a JSON array' }.to_json)
              end

              case Service::BehaviorEvents::RecordEvents.new.call(user_id:, events:)
              in Success(api_result)
                response.status = api_result.http_status_code
                { success: true, message: api_result.message }.to_json
              in Failure(api_result)
                response.status = api_result.http_status_code
                api_result.to_json
              end
            rescue JSON::ParserError => e
              response.status = 400
              { error: 'Invalid JSON', details: e.message }.to_json
            end

            # GET /api/behavior/:user_id/events
            r.get do
              limit = (r.params['limit'] || 5000).to_i

              case Service::BehaviorEvents::ListEvents.new.call(user_id:, limit:)
              in Success(api_result)
                response.status = api_result.http_status_code
                {
                  success: true,
                  data:    Representer::BehaviorEventsList.from_entities(api_result.message)
                }.to_json
              in Failure(api_result)
                response.status = api_result.http_status_code
                api_result.to_json
              end
            end
          end
        end
      end
    end
  end
end
