# frozen_string_literal: true

require 'sequel'
require 'figaro'
require 'roda'
require 'logger'

module SurveyTracker
  # Configuration for the API
  class Api < Roda
    plugin :environments

    Figaro.application = Figaro::Application.new(
      environment: environment, # rubocop:disable Style/HashSyntax
      path: File.join(__dir__, 'secrets.yml')
    )
    Figaro.load
    def self.config = Figaro.env

    db_url = ENV['DATABASE_URL']
    if db_url.start_with?('sqlite://')
      # Resolve relative SQLite paths against the project root
      pure_path = db_url.sub('sqlite://', '')
      unless pure_path.start_with?('/') || pure_path.match?(/^[a-zA-Z]:/)
        root = File.expand_path('../..', __dir__)
        db_url = "sqlite://#{File.join(root, pure_path)}"
      end
    end

    Sequel.default_timezone = :utc
    Sequel.application_timezone = :utc

    db_logger = (environment == :development ? Logger.new($stderr) : nil)
    @db = Sequel.connect(db_url, logger: db_logger)
    def self.db = @db # rubocop:disable Style/TrivialAccessors
  end
end
