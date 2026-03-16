class BiddingRequest < ApplicationRecord
  belongs_to :bidding_round
  belongs_to :work_category
  belongs_to :artisan
  belongs_to :replaced_by, class_name: "BiddingRequest", optional: true

  STATUSES = %w[pending sent responded declined replaced expired].freeze

  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :token, presence: true, uniqueness: true
  validates :artisan_id, uniqueness: { scope: %i[bidding_round_id work_category_id] }

  before_validation :generate_token, on: :create

  after_update_commit :broadcast_status_change, if: :saved_change_to_status?

  scope :active, -> { where.not(status: "replaced") }
  scope :pending_send, -> { where(status: "pending") }

  def responded?
    status == "responded"
  end

  def declined?
    status == "declined"
  end

  def awaiting?
    %w[pending sent].include?(status)
  end

  def terminal?
    %w[responded declined expired replaced].include?(status)
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  # rubocop:disable Metrics/MethodLength
  def broadcast_status_change
    project = bidding_round.project
    broadcast_replace_to(
      "bidding_round_#{bidding_round_id}_requests",
      target: "bidding_request_#{id}",
      partial: "bidding_rounds/bidding_request_row",
      locals: { bidding_request: self, project: project }
    )
    broadcast_replace_to(
      "bidding_round_#{bidding_round_id}_requests",
      target: "bidding_progress",
      partial: "bidding_rounds/progress_bar",
      locals: { bidding_round: bidding_round }
    )
  rescue StandardError => e
    Rails.logger.error("BiddingRequest#broadcast_status_change failed: #{e.message}")
  end
  # rubocop:enable Metrics/MethodLength
end
