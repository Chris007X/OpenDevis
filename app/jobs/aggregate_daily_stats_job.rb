# Nightly job — aggregates raw events into analytics_daily_stats for fast dashboard queries.
# Schedule via Solid Queue recurring tasks (config/recurring.yml) or a cron.
class AggregateDailyStatsJob < ApplicationJob
  queue_as :analytics

  # date defaults to yesterday so the full day's data is available
  def perform(date = Date.yesterday)
    date = date.is_a?(Date) ? date : Date.parse(date.to_s)
    AnalyticsDailyStat.aggregate_for(date)
  end
end
