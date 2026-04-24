# frozen_string_literal: true

# Code coverage (must load before application code)
require 'simplecov'
SimpleCov.start

# Environment setup
ENV['RACK_ENV'] = 'test'

# Load application and dependencies
require_relative '../../require_app'
require_app

require 'minitest/autorun'
require 'minitest/spec' # Enable spec-style describe/it blocks
require 'rack/test'

require_relative 'support/test_helpers'

# Database setup (run ONCE before all tests)
DB = SurveyTracker::Api.db

# Ensure the test DB schema is up-to-date. Without this, a developer who pulls
# new migrations but forgets `RACK_ENV=test bundle exec rake db:migrate` hits
# obscure MassAssignmentRestriction / NoSuchColumn errors rooted in stale
# schema. Running migrations here makes the test DB self-healing.
Sequel.extension :migration
Sequel::Migrator.run(DB, File.expand_path('../db/migrations', __dir__))

# Wipe data but preserve schema_info — wiping the version row makes the
# migrator re-attempt migration 001 on the next run, which collides with the
# already-existing tables.
(DB.tables - %i[schema_info]).each { |table| DB[table].delete }

# Transaction wrapping (each test runs in rolled-back transaction)
class Minitest::Spec # rubocop:disable Style/ClassAndModuleChildren
  def run
    DB.transaction(rollback: :always, savepoint: true, auto_savepoint: true) do
      super
    end
  end
end
