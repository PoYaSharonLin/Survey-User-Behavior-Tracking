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
      path: File.expand_path('backend_app/config/secrets.yml')
    )
    Figaro.load

    def self.config = Figaro.env

    db_url = ENV['DATABASE_URL']

    Sequel.default_timezone = :utc
    Sequel.application_timezone = :utc

    db_logger = environment == :development ? Logger.new($stderr) : nil
    @db = Sequel.connect(db_url, logger: db_logger)
    def self.db = @db # rubocop:disable Style/TrivialAccessors
  end
end
