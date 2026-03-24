
require './config/environment'
require 'benchmark'

begin
  uid = '12345678'
  session = SurveyTracker::Database::Repository::SurveySessions.new.find_by_user_id(uid)
  
  if session
    puts "Found session #{session.id} for user #{uid}"
    
    records = nil
    time_db = Benchmark.realtime do
      records = SurveyTracker::Database::Repository::BehaviorEvents.new.list_by_session(
        survey_session_id: session.id,
        limit: 5000
      )
    end
    puts "DB Fetch for #{records.count} records: #{time_db.round(4)}s"
    
    entities = nil
    time_entities = Benchmark.realtime do
      entities = records.map do |r|
        SurveyTracker::Domain::BehaviorEvents::BehaviorEvent.new(
          id:               r.id,
          survey_session_id: r.survey_session_id,
          event_type:       r.event_type,
          x:                r.x,
          y:                r.y,
          element_selector: r.element_selector,
          text_content:     r.text_content,
          timestamp:        r.timestamp,
          extra:            r.extra,
          created_at:       r.created_at
        )
      end
    end
    puts "Entity mapping: #{time_entities.round(4)}s"
    
    json = nil
    time_json = Benchmark.realtime do
      json = SurveyTracker::Representer::BehaviorEventsList.from_entities(entities).to_json
    end
    puts "JSON Serialization: #{time_json.round(4)}s"
  else
    puts "No session found for #{uid}"
  end
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end
