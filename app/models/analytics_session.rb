class AnalyticsSession < ApplicationRecord
  # NOTE: foreign_key on session_id string — no AR-managed FK constraint
  has_many :analytics_events, foreign_key: :session_id, primary_key: :session_id, dependent: :destroy

  validates :session_id, presence: true, uniqueness: true

  scope :recent, ->(days = 7) { where("started_at > ?", days.days.ago) }
  scope :converted, -> { where(converted: true) }
  scope :abandoned, -> { where(converted: false) }

  def self.conversion_rate(days = 7)
    total = recent(days).count
    return 0.0 if total.zero?

    (recent(days).converted.count.to_f / total * 100).round(2)
  end

  def self.avg_duration(days = 7)
    recent(days).where.not(duration_seconds: nil).average(:duration_seconds)&.round(1) || 0.0
  end

  # Top drop-off pages sorted by abandonment count
  def self.drop_off_pages(days = 7)
    recent(days).abandoned
                .where.not(drop_off_page: nil)
                .group(:drop_off_page)
                .count
                .sort_by { |_, v| -v }
                .to_h
  end
end
