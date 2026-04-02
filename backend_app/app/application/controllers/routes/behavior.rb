# frozen_string_literal: true

require 'json'
require 'dry/monads'

module SurveyTracker
  module Routes
    # Behavior trajectory routes:
    #   POST /api/behavior/:user_id/events  → record a batch of trajectories
    #   GET  /api/behavior/:user_id/events  → list all trajectories for this session
    #   POST /api/behavior/:user_id/upload  → upload binary blob to S3
    class Behavior < Roda
      include Dry::Monads[:result]

      plugin :all_verbs
      plugin :request_headers

      route do |r|
        response['Content-Type'] = 'application/json'

        r.on String do |user_id|

          r.on 'events' do
            # POST /api/behavior/:user_id/events
            # Body: { "trajectories": [ { "type": "MM"|"PC"|..., "events": [[x,y,type,ts,...], ...] }, ... ] }
            r.post do
              body         = JSON.parse(r.body.read, symbolize_names: true)
              trajectories = body[:trajectories]

              unless trajectories.is_a?(Array)
                response.status = 400
                next({ error: 'trajectories must be a JSON array' }.to_json)
              end

              case Service::BehaviorEvents::RecordEvents.new.call(user_id:, trajectories:)
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
                  data:    Representer::TrajectoryList.from_entities(api_result.message)
                }.to_json
              in Failure(api_result)
                response.status = api_result.http_status_code
                api_result.to_json
              end
            end
          end

          # POST /api/behavior/:user_id/upload
          # Body: raw binary blob (SBEH magic header + uid + msgpack payload)
          r.on 'upload' do
            r.post do
              binary_data = r.body.read

              if binary_data.nil? || binary_data.empty?
                response.status = 400
                next({ error: 'empty body' }.to_json)
              end

              result = Infrastructure::S3Service.new.upload_binary(user_id, binary_data)

              if result[:success]
                response.status = 201
                { success: true, key: result[:key] }.to_json
              else
                response.status = 502
                { success: false, error: result[:error] }.to_json
              end
            end
          end

        end
      end
    end
  end
end
