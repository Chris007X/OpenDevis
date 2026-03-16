class AnalyticsDashboardController < ApplicationController
  before_action :require_admin!

  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def index
    @days = params.fetch(:days, 7).to_i.clamp(1, 365)

    @total_events    = AnalyticsEvent.recent(@days).count
    @total_sessions  = AnalyticsSession.recent(@days).count
    @unique_users    = AnalyticsEvent.recent(@days).where.not(user_id: nil).distinct.count(:user_id)
    @conversion_rate = AnalyticsSession.conversion_rate(@days)
    @avg_duration    = AnalyticsSession.avg_duration(@days)

    @event_summary   = AnalyticsEvent.event_summary(@days)
    @top_pages       = AnalyticsEvent.recent(@days)
                                     .where(event_type: "page_view")
                                     .group(:page_path)
                                     .count
                                     .sort_by { |_, v| -v }
                                     .first(10)
                                     .to_h

    @drop_off_pages  = AnalyticsSession.drop_off_pages(@days).first(10).to_h
    @avg_load_times  = AnalyticsEvent.avg_load_times(@days).first(10).to_h

    @recent_events   = AnalyticsEvent.order(created_at: :desc).limit(25)

    # Active now: sessions with event activity in the last 10 minutes
    active_user_ids = AnalyticsSession
                        .where("ended_at > ?", 10.minutes.ago)
                        .where.not(user_id: nil)
                        .pluck(:user_id)
    @active_users = User.where(id: active_user_ids).to_a

    # Recent user activity: one row per logged-in user for the selected period
    recent_user_ids = AnalyticsEvent.recent(@days).where.not(user_id: nil).distinct.pluck(:user_id)
    users_map = User.where(id: recent_user_ids).index_by { |u| u.id.to_s }

    @recent_user_activity = recent_user_ids.filter_map do |uid|
      user = users_map[uid.to_s]
      next unless user

      user_events  = AnalyticsEvent.recent(@days).where(user_id: uid.to_s)
      last_event   = user_events.order(created_at: :desc).first
      last_session = AnalyticsSession.where(user_id: uid.to_s).order(started_at: :desc).first

      {
        user:         user,
        event_count:  user_events.count,
        last_page:    last_event&.page_path,
        last_seen:    last_event&.created_at,
        time_spent_s: last_session&.duration_seconds || 0
      }
    end.sort_by { |h| -(h[:last_seen]&.to_i || 0) }

    @funnel_reports  = FunnelAnalyzer.all_names.map do |name|
      FunnelAnalyzer.new(name).report(days: @days)
    end

    # Daily events for the sparkline (last @days days, capped at 30 for readability)
    sparkline_days = [ @days, 30 ].min
    @daily_events  = AnalyticsEvent
                       .where("created_at > ?", sparkline_days.days.ago)
                       .group("DATE(created_at)")
                       .count
                       .transform_keys { |d| d.to_s }
  end

  private

  def require_admin!
    redirect_to root_path, alert: "Accès non autorisé." unless current_user&.admin?
  end
end
