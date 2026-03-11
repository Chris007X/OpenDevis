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
end
