class AnalyticsController < ApplicationController
  include Trackable

  # Skip auth — we receive events from anonymous visitors too.
  skip_before_action :authenticate_user!

  # Pundit: we authorize manually below.
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def create
    ev = event_params

    AnalyticsTracker.track(
      event_type:        ev[:event_type],
      session_id:        analytics_session_id,
      user_id:           current_analytics_user_id,
      page_path:         ev[:page_path],
      referrer:          ev[:referrer],
      user_agent:        request.user_agent,
      ip_address:        anonymized_ip,
      page_load_time_ms: ev[:page_load_time_ms]&.to_i,
      completed:         ev[:completed] == true || ev[:completed] == "true",
      properties:        ev[:properties].to_h
    )

    head :no_content
  end

  private

  def event_params
    params.require(:event).permit(
      :event_type, :page_path, :referrer, :page_load_time_ms, :completed,
      properties: {}
    )
  end
end
