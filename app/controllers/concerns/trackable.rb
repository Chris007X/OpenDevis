# Include in ApplicationController (or individual controllers) to get one-line event tracking.
#
# Usage:
#   track_event("page_view")
#   track_event("form_submit", completed: true, properties: { step: 4 })
module Trackable
  extend ActiveSupport::Concern

  included do
    helper_method :analytics_session_id
  end

  private

  # Tracks an event using request context automatically.
  def track_event(event_type, completed: false, properties: {}, page_load_time_ms: nil)
    AnalyticsTracker.track(
      event_type: event_type,
      session_id: analytics_session_id,
      user_id: current_analytics_user_id,
      page_path: request.path,
      referrer: request.referer,
      user_agent: request.user_agent,
      ip_address: anonymized_ip,
      page_load_time_ms: page_load_time_ms,
      completed: completed,
      properties: properties
    )
  end

  # Records a funnel step into analytics_funnels synchronously (funnel events are rare
  # and we want the time_to_complete to be accurate, so no background job here).
  def track_funnel_step(funnel_name, step_number, step_name, completed: true)
    AnalyticsFunnel.create!(
      funnel_name: funnel_name,
      user_id: current_analytics_user_id,
      session_id: analytics_session_id,
      step_number: step_number,
      step_name: step_name,
      completed: completed
    )
  rescue StandardError => e
    Rails.logger.warn "[Analytics] Funnel track failed: #{e.message}"
  end

  # Persistent session ID stored in the cookie session — survives across requests.
  def analytics_session_id
    session[:analytics_session_id] ||= SecureRandom.uuid
  end

  # Returns the user id as a string, or nil for anonymous visitors.
  def current_analytics_user_id
    return current_user.id.to_s if respond_to?(:current_user, true) && current_user.present?
    return current_artisan.id.to_s if respond_to?(:current_artisan, true) && current_artisan.present?

    nil
  end

  # Stores only the first 3 octets of IPv4 (e.g. 192.168.1.x) to avoid storing PII.
  def anonymized_ip
    ip = request.remote_ip.to_s
    parts = ip.split(".")
    return ip unless parts.length == 4  # skip IPv6 for now

    "#{parts[0..2].join(".")}.0"
  end
end
