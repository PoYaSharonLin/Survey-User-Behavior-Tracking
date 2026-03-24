
# frozen_string_literal: true
require_relative '../require_app'
require_app

require 'csv'
require 'json'

# --- Configuration ---
# Set the User ID you want to export data for
TARGET_UID = ARGV[0] || '12345678'
OUTPUT_FILE = "export_#{TARGET_UID}.csv"

puts "🔍 Looking up data for UID: #{TARGET_UID}..."

begin
  # 1. Find the session
  session = SurveyTracker::Database::Repository::SurveySessions.new.find_by_user_id(TARGET_UID)
  
  if session.nil?
    puts "❌ Error: No session found for user_id '#{TARGET_UID}'"
    exit 1
  end

  puts "✅ Found session ID: #{session.id}"
  puts "📊 Metadata: #{session.metadata}"

  # 2. Get behavior events
  events = SurveyTracker::Api.db[:behavior_events]
            .where(survey_session_id: session.id)
            .order(:timestamp)
            .all

  puts "📈 Found #{events.count} behavior events."

  if events.empty?
    puts "⚠️ No events recorded for this session."
    exit 0
  end

  # 3. Export to CSV
  CSV.open(OUTPUT_FILE, "wb") do |csv|
    # Header row
    csv << [
      "ID", "Event Type", "X", "Y", "Selector", 
      "Content", "Timestamp", "Created At"
    ]
    
    events.each do |e|
      csv << [
        e[:id],
        e[:event_type],
        e[:x],
        e[:y],
        e[:element_selector],
        e[:text_content],
        e[:timestamp],
        e[:created_at]
      ]
    end
  end

  puts "🚀 Successfully exported data to: #{OUTPUT_FILE}"
  puts "   (First 5 records printed below:)"
  puts "-" * 40
  events.first(5).each do |e|
    puts "[#{e[:timestamp]}] #{e[:event_type].ljust(10)} | x: #{e[:x].to_s.ljust(4)} y: #{e[:y].to_s.ljust(4)} | #{e[:element_selector]}"
  end
  puts "-" * 40

rescue => e
  puts "💥 An error occurred: #{e.message}"
  puts e.backtrace.first(10)
end
