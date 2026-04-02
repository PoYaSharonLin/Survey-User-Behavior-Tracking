
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

  # 2. Get trajectories
  trajectories = SurveyTracker::Api.db[:trajectories]
                  .where(survey_session_id: session.id)
                  .order(:created_at)
                  .all

  puts "📈 Found #{trajectories.count} trajectories."

  if trajectories.empty?
    puts "⚠️ No trajectories recorded for this session."
    exit 0
  end

  # 3. Export to CSV (one row per inner event, flattened from trajectories)
  CSV.open(OUTPUT_FILE, "wb") do |csv|
    csv << ["Trajectory ID", "Type", "Event Index", "x", "y", "Event Name", "Timestamp (ms)", "Extra...", "Created At"]

    trajectories.each do |traj|
      events = JSON.parse(traj[:events]) rescue []
      events.each_with_index do |evt, idx|
        csv << [traj[:id], traj[:trajectory_type], idx, *evt, traj[:created_at]]
      end
    end
  end

  puts "🚀 Successfully exported data to: #{OUTPUT_FILE}"
  puts "   (First 5 trajectories printed below:)"
  puts "-" * 40
  trajectories.first(5).each do |t|
    puts "[#{t[:created_at]}] #{t[:trajectory_type].ljust(3)} | #{t[:events][0..80]}"
  end
  puts "-" * 40

rescue => e
  puts "💥 An error occurred: #{e.message}"
  puts e.backtrace.first(10)
end
