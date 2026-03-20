# frozen_string_literal: true

require 'dry/operation'
require_relative '../responses/api_result'

module SurveyTracker
  module Service
    # Base class for all service operations
    class ApplicationOperation < Dry::Operation
      private

      def ok(message) = Response::ApiResult.new(status: :ok, message:)
      def created(message) = Response::ApiResult.new(status: :created, message:)
      def bad_request(message) = Response::ApiResult.new(status: :bad_request, message:)
      def not_found(message) = Response::ApiResult.new(status: :not_found, message:)
      def internal_error(message) = Response::ApiResult.new(status: :internal_error, message:)
    end
  end
end
