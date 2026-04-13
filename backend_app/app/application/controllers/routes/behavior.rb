# frozen_string_literal: true

require 'json'
require 'dry/monads'

module SurveyTracker
  module Routes
    # Behavior trajectory routes:
    #   POST /api/behavior/:user_id/events          → record a batch of trajectories
    #   GET  /api/behavior/:user_id/events          → list all trajectories for this session
    #   GET  /api/behavior/:user_id/presigned-url   → get a presigned PUT URL for direct S3 upload
    #   POST /api/behavior/:user_id/confirm-upload  → save the S3 key after a successful upload
    #   GET  /api/behavior/:user_id/download-url    → get a presigned GET URL for downloading the object
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

          # GET /api/behavior/:user_id/presigned-url
          # Returns a short-lived (10 min) presigned PUT URL for the frontend to upload
          # the binary blob directly to S3. Generate this only at submit time.
          r.on 'presigned-url' do
            r.get do
              result = Infrastructure::S3Service.new.presign_upload_url(user_id)

              if result[:success]
                response.status = 200
                { url: result[:url], key: result[:key], expires_at: result[:expires_at] }.to_json
              else
                response.status = 502
                { success: false, error: result[:error] }.to_json
              end
            end
          end

          # POST /api/behavior/:user_id/confirm-upload
          # Body: { "key": "behavior_data/abc123_1712345678.bin" }
          # Called by the frontend after the S3 PUT succeeds. Persists the S3 key
          # against the user's session so it can be retrieved later.
          r.on 'confirm-upload' do
            r.post do
              body = JSON.parse(r.body.read, symbolize_names: true)
              key  = body[:key]

              if key.nil? || key.strip.empty?
                response.status = 400
                next({ error: 'key is required' }.to_json)
              end

              session = Database::Repository::SurveySessions.new.update_s3_key(
                user_id:,
                s3_key: key
              )

              if session
                response.status = 200
                { success: true }.to_json
              else
                response.status = 404
                { success: false, error: 'session not found' }.to_json
              end
            rescue JSON::ParserError => e
              response.status = 400
              { error: 'Invalid JSON', details: e.message }.to_json
            end
          end

          # GET /api/behavior/:user_id/download-url
          # Looks up the stored S3 key for this user and returns a presigned GET URL
          # (valid 1 hour) so a researcher can download the object without AWS credentials.
          r.on 'download-url' do
            r.get do
              session = Database::Repository::SurveySessions.new.find_by_user_id(user_id)

              unless session
                response.status = 404
                next({ error: 'session not found' }.to_json)
              end

              unless session.s3_key
                response.status = 404
                next({ error: 'no upload on record for this user' }.to_json)
              end

              result = Infrastructure::S3Service.new.presign_download_url(session.s3_key)

              if result[:success]
                response.status = 200
                { url: result[:url], expires_at: result[:expires_at] }.to_json
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
