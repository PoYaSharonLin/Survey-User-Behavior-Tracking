# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Behavior Routes' do
  before do
    # Create a session to belong events to
    @session = SurveyTracker::Database::Orm::SurveySession.create(
      user_id: 'track_user',
      started_at: Time.now.utc
    )
  end

  it 'should record a batch of events' do
    payload = {
      events: [
        {
          event_type: 'mousemove',
          x: 100,
          y: 200,
          timestamp: Time.now.utc.iso8601
        },
        {
          event_type: 'click',
          element_selector: '#submit-btn',
          timestamp: Time.now.utc.iso8601
        },
        {
          event_type: 'slider',
          element_selector: '.native-slider-1',
          x: 450,
          y: 350,
          timestamp: Time.now.utc.iso8601,
          extra: { value: 5 }.to_json
        }
      ]
    }

    header 'CONTENT_TYPE', 'application/json'
    post "/api/behavior/#{@session.user_id}/events", payload.to_json

    _(last_response.status).must_equal 201
    _(json_response[:success]).must_equal true
    _(json_response[:message]).must_match(/3 event\(s\) recorded/)
  end

  it 'should list events for a session' do
    # Pre-populate some events
    repo = SurveyTracker::Database::Repository::BehaviorEvents.new
    repo.create_batch(
      survey_session_id: @session.id,
      events: [
        { event_type: 'mousemove', timestamp: Time.now.utc },
        { event_type: 'scroll', timestamp: Time.now.utc }
      ]
    )

    get "/api/behavior/#{@session.user_id}/events"

    _(last_response.status).must_equal 200
    _(json_response[:success]).must_equal true
    _(json_response[:data].size).must_equal 2
  end
end
