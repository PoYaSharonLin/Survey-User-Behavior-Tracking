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
      'pointer-move', 'pointer-down', 'pointer-up', 'pointer-over', 'pointer-out',
      'key-down', 'key-up', 'highlight', 'scroll', 'slider-change',
      'focus', 'blur', 'visibility-change', 'page-show', 'page-hide'
    )

    # Flexible datetime that accepts Ruby Time objects (returned by SQLite/Sequel)
    # or DateTime objects — strict Types::DateTime only accepts DateTime, not Time
    FlexibleDateTime = Types.Instance(::Time) | Types.Instance(::DateTime)
  end
end
