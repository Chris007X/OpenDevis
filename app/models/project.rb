class Project < ApplicationRecord
  belongs_to :user
  has_many :rooms, dependent: :destroy
  has_many :work_items, through: :rooms
  has_many :documents, dependent: :destroy
  has_one :bidding_round, dependent: :destroy

  enum :status, { draft: "draft", sent: "sent", accepted: "accepted", rejected: "rejected" }, default: "draft"

  validates :status, presence: true

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
