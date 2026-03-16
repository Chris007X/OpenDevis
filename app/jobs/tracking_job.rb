class TrackingJob < ApplicationJob
  queue_as :analytics

  # Arguments are positional (ActiveJob serializes them) — see AnalyticsTracker.track
  def perform(event_type, session_id, user_id, page_path, referrer, user_agent,
              ip_address, page_load_time_ms, completed, properties)
    AnalyticsTracker.record!(
      event_type: event_type,
      session_id: session_id,
      user_id: user_id,
      page_path: page_path,
      referrer: referrer,
      user_agent: user_agent,
      ip_address: ip_address,
      page_load_time_ms: page_load_time_ms,
      completed: completed,
      properties: properties || {}
    )
  end
end
