class Project < ApplicationRecord
  belongs_to :user
  has_many :rooms, dependent: :destroy
  has_many :work_items, through: :rooms
  has_many :documents, dependent: :destroy
  has_one :bidding_round, dependent: :destroy

  enum :status, { in_progress: "in_progress", quote_requested: "quote_requested",
                   quote_received: "quote_received", archived: "archived" }, default: "in_progress"

  validates :status, presence: true

  def total_incVAT_for_standing(level)
    work_items.select { |i| i.standing_level == level }
              .sum { |i| (i.quantity || 0) * (i.unit_price_exVAT || 0) * (1 + ((i.vat_rate || 0) / 100.0)) }
  end

  def recompute_totals!
    items = work_items.to_a
    self.total_exVAT = items.sum { |i| (i.quantity || 0) * (i.unit_price_exVAT || 0) }
    self.total_incVAT = items.sum do |i|
      exvat = (i.quantity || 0) * (i.unit_price_exVAT || 0)
      exvat * (1 + ((i.vat_rate || 0) / 100.0))
    end
    save!
  end
end
