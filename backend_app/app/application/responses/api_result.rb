# frozen_string_literal: true

module SurveyTracker
  module Response
    # Unified response wrapper for all service operations
    class ApiResult
      HTTP_STATUS_MAP = {
        ok:             200,
        created:        201,
        no_content:     204,
        bad_request:    400,
        unauthorized:   401,
        forbidden:      403,
        not_found:      404,
        internal_error: 500
      }.freeze

      attr_reader :status, :message

      def initialize(status:, message:)
        @status  = status
        @message = message
      end

      def http_status_code
        HTTP_STATUS_MAP.fetch(@status, 500)
      end

      def to_json(*_args)
        { success: false, error: @message }.to_json
      end
    end
  end
end
