class AnalyticsDashboardController < ApplicationController
  before_action :require_admin!

  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def index
    @tab  = params[:tab].presence_in(%w[overview users]) || "overview"
    @days = params.fetch(:days, 7).to_i.clamp(1, 365)

    if @tab == "users"
      load_all_users
      return
    end

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

    load_active_users

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

  def user_detail
    @user = User.find(params[:user_id])
    @days = params.fetch(:days, 30).to_i.clamp(1, 365)

    @events = AnalyticsEvent
                .where(user_id: @user.id.to_s)
                .where("created_at > ?", @days.days.ago)
                .order(created_at: :desc)

    @sessions = AnalyticsSession
                  .where(user_id: @user.id.to_s)
                  .where("started_at > ?", @days.days.ago)
                  .order(started_at: :desc)

    @pages_visited = @events.where(event_type: "page_view")
                             .group(:page_path)
                             .count
                             .sort_by { |_, v| -v }
                             .to_h

    @total_time_s = @sessions.sum(:duration_seconds)
  end

  def active_users
    load_active_users
    render partial: "active_users"
  end

  private

  def load_all_users
    # All users who ever fired an analytics event, newest activity first
    user_ids = AnalyticsEvent.where.not(user_id: nil).distinct.pluck(:user_id)
    users_map = User.where(id: user_ids).index_by { |u| u.id.to_s }

    @all_users = user_ids.filter_map do |uid|
      user = users_map[uid.to_s]
      next unless user

      last_event   = AnalyticsEvent.where(user_id: uid.to_s).order(created_at: :desc).first
      last_session = AnalyticsSession.where(user_id: uid.to_s).order(started_at: :desc).first
      first_seen   = AnalyticsEvent.where(user_id: uid.to_s).order(created_at: :asc).first

      {
        user:          user,
        event_count:   AnalyticsEvent.where(user_id: uid.to_s).count,
        session_count: AnalyticsSession.where(user_id: uid.to_s).count,
        last_seen:     last_event&.created_at,
        first_seen:    first_seen&.created_at,
        last_page:     last_event&.page_path,
        total_time_s:  AnalyticsSession.where(user_id: uid.to_s).sum(:duration_seconds)
      }
    end.sort_by { |r| -(r[:last_seen]&.to_i || 0) }
  end

  def load_active_users
    active_sessions = AnalyticsSession
                        .where("ended_at > ?", 10.minutes.ago)
                        .where.not(user_id: nil)
                        .order(ended_at: :desc)

    user_ids = active_sessions.pluck(:user_id).uniq
    users_map = User.where(id: user_ids).index_by { |u| u.id.to_s }

    @active_users = active_sessions.map do |s|
      user = users_map[s.user_id.to_s]
      next unless user

      seconds_ago = (Time.current - s.ended_at).to_i
      { user: user, current_page: s.last_page, seconds_ago: seconds_ago }
    end.compact.uniq { |r| r[:user].id }
  end

  def require_admin!
    redirect_to root_path, alert: "Accès non autorisé." unless current_user&.admin?
  end
end
