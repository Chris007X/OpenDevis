class FinalSelection < ApplicationRecord
  belongs_to :bidding_round
  belongs_to :work_category
  belongs_to :bidding_request

  validates :bidding_round_id, uniqueness: { scope: :work_category_id }

  delegate :artisan, :price_total, to: :bidding_request
end
