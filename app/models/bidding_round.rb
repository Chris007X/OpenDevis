class BiddingRound < ApplicationRecord
  belongs_to :project
  has_many :bidding_requests, dependent: :destroy
  has_many :final_selections, dependent: :destroy

  STATUSES = %w[draft sent in_progress completed cancelled].freeze
  STANDING_LABELS = { 1 => "Éco", 2 => "Standard", 3 => "Premium" }.freeze

  validates :standing_level, presence: true, inclusion: { in: [1, 2, 3] }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :deadline, presence: true
  validates :project_id, uniqueness: true

  def standing_label
    STANDING_LABELS[standing_level]
  end

  def responses_received
    bidding_requests.where(status: "responded").count
  end

  def total_requests
    bidding_requests.where.not(status: "replaced").count
  end

  def all_responded?
    active_requests = bidding_requests.where.not(status: %w[replaced pending])
    active_requests.any? && active_requests.all? { |r| %w[responded declined expired].include?(r.status) }
  end

  def deadline_passed?
    deadline < Time.current
  end

  def ready_for_review?
    all_responded? || deadline_passed?
  end

  def total_artisan_price
    final_selections.joins(:bidding_request).sum("bidding_requests.price_total")
  end
end
