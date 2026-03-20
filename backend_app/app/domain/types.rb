# frozen_string_literal: true

require 'dry-types'
require 'dry-struct'

module SurveyTracker
  # Shared constrained types for domain entities.
  # Types live in the domain layer because they express domain vocabulary.
  module Types
    include Dry.Types()

    # Basic types
    NonEmptyString = Types::String.constrained(min_size: 1)

    # Event type enum — all valid behavior event classifications
    BehaviorEventType = Types::String.enum(
      'mousemove', 'click', 'highlight', 'hover', 'scroll', 'slider'
    )
  end
end
