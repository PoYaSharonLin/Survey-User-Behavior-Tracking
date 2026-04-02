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
      def upload_session_data(user_id, events)
        return if events.empty?

        key = "behavior_data/#{user_id}_#{Time.now.to_i}.json"
        body = {
          user_id: user_id,
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

      # Uploads a raw binary behavior blob to S3.
      # The blob is produced by the frontend tracker and contains a SBEH header
      # with the uid embedded, followed by a msgpack-encoded trajectory array.
      def upload_binary(user_id, binary_data)
        key = "behavior_data/#{user_id}_#{Time.now.to_i}.bin"

        @s3_client.put_object(
          bucket:       @bucket_name,
          key:          key,
          body:         binary_data,
          content_type: 'application/octet-stream'
        )

        { success: true, key: key }
      rescue StandardError => e
        { success: false, error: e.message }
      end
    end
  end
end
