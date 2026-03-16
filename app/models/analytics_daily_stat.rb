class AnalyticsDailyStat < ApplicationRecord
  validates :date, presence: true, uniqueness: true

  scope :between, ->(from, to) { where(date: from..to) }
  scope :last_n_days, ->(n) { where(date: n.days.ago.to_date..) }

  # Upsert aggregated stats for a given date (call from a nightly job)
  def self.aggregate_for(date)
    range = date.beginning_of_day..date.end_of_day

    unique_users     = AnalyticsEvent.where(created_at: range).where.not(user_id: nil).distinct.count(:user_id)
    total_events     = AnalyticsEvent.where(created_at: range).count
    day_sessions     = AnalyticsSession.where(started_at: range)
    total_sessions   = day_sessions.count
    avg_duration     = day_sessions.average(:duration_seconds)&.round(1) || 0.0
    converted        = day_sessions.where(converted: true).count
    conversion_rate  = total_sessions.zero? ? 0.0 : (converted.to_f / total_sessions * 100).round(2)

    find_or_initialize_by(date: date).update!(
      unique_users: unique_users,
      total_events: total_events,
      total_sessions: total_sessions,
      avg_session_duration: avg_duration,
      conversion_rate: conversion_rate
    )
  end
end
