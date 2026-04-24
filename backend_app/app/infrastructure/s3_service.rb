# frozen_string_literal: true

require 'aws-sdk-s3'
require 'json'

module SurveyTracker
  module Infrastructure
    # Service to upload behavior data to Amazon S3
    class S3Service
      def initialize
        @config = SurveyTracker::Api.config
        @s3_client = Aws::S3::Client.new(
          region:            @config.AWS_REGION,
          access_key_id:     @config.AWS_ACCESS_KEY_ID,
          secret_access_key: @config.AWS_SECRET_ACCESS_KEY
        )
        @bucket_name = @config.S3_BUCKET_NAME
      end

      # Uploads behavior events for a specific session as a JSON file
      def upload_session_data(respondent_id, events)
        return if events.empty?

        key = "behavior_data/#{respondent_id}_#{Time.now.to_i}.json"
        body = {
          respondent_id: respondent_id,
          exported_at: Time.now.utc.iso8601,
          events: events.map(&:to_h)
        }.to_json

        @s3_client.put_object(
          bucket: @bucket_name,
          key:    key,
          body:   body,
          content_type: 'application/json'
        )

        { success: true, key: key }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      # Returns a presigned PUT URL for the frontend to upload a binary blob directly to S3.
      # Expires in 10 minutes — generated on submit click so expiry is not a concern.
      def presign_upload_url(respondent_id)
        key = "behavior_data/#{respondent_id}_#{Time.now.to_i}.bin"
        presigner = Aws::S3::Presigner.new(client: @s3_client)
        url = presigner.presigned_url(
          :put_object,
          bucket:       @bucket_name,
          key:          key,
          expires_in:   600,
          content_type: 'application/octet-stream'
        )
        expires_at = (Time.now.utc + 600).iso8601
        { success: true, url: url, key: key, expires_at: expires_at }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      # Applies a CORS policy to the bucket so browsers can PUT objects via presigned URLs.
      # Call once during setup: `bundle exec rake s3:configure_cors`
      # allowed_origins: array of origins, e.g. ["http://localhost:8080", "https://example.com"]
      def configure_bucket_cors(allowed_origins: ['*'])
        @s3_client.put_bucket_cors(
          bucket: @bucket_name,
          cors_configuration: {
            cors_rules: [
              {
                allowed_headers: ['*'],
                allowed_methods: %w[PUT GET HEAD],
                allowed_origins: allowed_origins,
                expose_headers:  ['ETag'],
                max_age_seconds: 3000
              }
            ]
          }
        )
        { success: true }
      rescue StandardError => e
        { success: false, error: e.message }
      end

      # Returns a presigned GET URL so a researcher can download the object without AWS credentials.
      # Default expiry: 1 hour.
      def presign_download_url(s3_key, expires_in: 3600)
        presigner = Aws::S3::Presigner.new(client: @s3_client)
        url = presigner.presigned_url(
          :get_object,
          bucket:     @bucket_name,
          key:        s3_key,
          expires_in: expires_in
        )
        expires_at = (Time.now.utc + expires_in).iso8601
        { success: true, url: url, expires_at: expires_at }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end
end
