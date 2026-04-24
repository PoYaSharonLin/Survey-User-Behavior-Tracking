# frozen_string_literal: true

require_relative '../spec_helper'

describe 'Behavior Routes' do
  before do
    @session = SurveyTracker::Database::Orm::SurveySession.create(
      respondent_id: 'track_user',
      started_at: Time.now.utc
    )
  end

  it 'should record a batch of events' do
    now_ms = (Time.now.utc.to_f * 1000).to_i
    payload = {
      events: [
        { type: 'pointer-move', x: 100, y: 200, ts: now_ms, pointerType: 'mouse' },
        { type: 'key-down', key: 'Enter', x: 300, y: 150, ts: now_ms, element: 'submit-btn' },
        { type: 'slider-change', x: 450, y: 350, ts: now_ms, element: 'q1-slider', value: 5, phase: 'release' }
      ]
    }

    header 'CONTENT_TYPE', 'application/json'
    post "/api/behavior/#{@session.respondent_id}/events", payload.to_json

    _(last_response.status).must_equal 201
    _(json_response[:success]).must_equal true
    _(json_response[:message]).must_match(/3 event\(s\) recorded/)
  end

end
