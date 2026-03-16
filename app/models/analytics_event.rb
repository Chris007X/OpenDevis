class AnalyticsEvent < ApplicationRecord
  validates :event_type, presence: true

  scope :by_user, ->(user_id) { where(user_id: user_id.to_s) }
  scope :by_page, ->(path) { where(page_path: path) }
  scope :by_type, ->(type) { where(event_type: type) }
  scope :recent, ->(days = 7) { where("created_at > ?", days.days.ago) }

  # Returns { event_type => count } sorted descending
  def self.event_summary(days = 7)
    recent(days).group(:event_type).count.sort_by { |_, v| -v }.to_h
  end

  # Returns { page_path => count } for uncompleted events (drop-offs)
  def self.drop_off_analysis(days = 7)
    recent(days).where(completed: false)
                .group(:page_path)
                .count
                .sort_by { |_, v| -v }
                .to_h
  end

  # Returns { source_label => count } for traffic source breakdown
  REFERRER_RULES = [
    [ /google\./i,    "Google" ],
    [ /bing\./i,      "Bing" ],
    [ /yahoo\./i,     "Yahoo" ],
    [ /facebook\.|fb\.com/i, "Facebook" ],
    [ /instagram\./i, "Instagram" ],
    [ /linkedin\./i,  "LinkedIn" ],
    [ /twitter\.|t\.co/i, "Twitter / X" ],
    [ /tiktok\./i,    "TikTok" ],
    [ /reddit\./i,    "Reddit" ],
    [ /opendevis\./i, nil ],  # self-referral → ignore (treat as direct)
  ].freeze

  def self.traffic_sources(days = 7)
    rows = recent(days).where(event_type: "page_view").pluck(:referrer)
    counts = Hash.new(0)
    rows.each do |ref|
      label = if ref.blank?
        "Direct"
      else
        rule = REFERRER_RULES.find { |pattern, _| ref.match?(pattern) }
        rule.nil? ? "Autre" : rule[1]  # nil label = self-referral, mapped to Direct below
      end
      next if label.nil?  # skip self-referrals
      counts[label] += 1
    end
    counts.sort_by { |_, v| -v }.to_h
  end

  # Average page load time per path
  def self.avg_load_times(days = 7)
    recent(days)
      .where.not(page_load_time_ms: nil)
      .group(:page_path)
      .average(:page_load_time_ms)
      .transform_values(&:to_i)
      .sort_by { |_, v| -v }
      .to_h
  end
end
