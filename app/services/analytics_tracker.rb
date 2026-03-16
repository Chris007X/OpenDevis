# AnalyticsTracker — server-side event tracking entry point.
#
# Usage from controllers (via the Trackable concern):
#   track_event("page_view", page_path: "/projects")
#   track_event("form_submit", page_path: "/wizard/step4", properties: { standing: "premium" })
#
# Direct usage:
#   AnalyticsTracker.track(event_type: "click", session_id: sid, user_id: uid, page_path: "/")
#
# All writes are async via TrackingJob to avoid blocking the request cycle.
class AnalyticsTracker
  # Public API — writes synchronously. Overhead is <5ms and analytics must never
  # crash the app, so all errors are rescued and logged.
  def self.track(event_type:, session_id: nil, user_id: nil, page_path: nil,
                 referrer: nil, user_agent: nil, ip_address: nil,
                 page_load_time_ms: nil, completed: false, properties: {})
    record!(
      event_type: event_type, session_id: session_id&.to_s, user_id: user_id&.to_s,
      page_path: page_path, referrer: referrer, user_agent: user_agent,
      ip_address: ip_address, page_load_time_ms: page_load_time_ms,
      completed: completed, properties: properties.to_h
    )
  rescue StandardError => e
    Rails.logger.warn "[Analytics] Track failed: #{e.message}"
  end

  # Called by TrackingJob — actual DB writes happen here.
  def self.record!(event_type:, session_id: nil, user_id: nil, page_path: nil,
                   referrer: nil, user_agent: nil, ip_address: nil,
                   page_load_time_ms: nil, completed: false, properties: {})
    event = AnalyticsEvent.create!(
      event_type: event_type,
      session_id: session_id,
      user_id: user_id,
      page_path: page_path,
      referrer: referrer,
      user_agent: user_agent,
      ip_address: ip_address,
      page_load_time_ms: page_load_time_ms,
      completed: completed,
      properties: properties
    )

    update_session!(session_id, user_id, page_path) if session_id.present?

    event
  end

  private_class_method def self.update_session!(session_id, user_id, page_path)
    session = AnalyticsSession.find_or_initialize_by(session_id: session_id)

    now = Time.current
    session.user_id       ||= user_id
    session.started_at    ||= now
    session.first_page    ||= page_path
    session.last_page       = page_path
    session.ended_at        = now
    session.events_count    = (session.events_count || 0) + 1
    session.duration_seconds = (now - session.started_at).to_i

    session.save!
  end
end
