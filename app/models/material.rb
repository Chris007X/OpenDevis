class Material < ApplicationRecord
  belongs_to :work_category
  has_many :work_items

  validates :public_price_exVAT, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :unit, presence: true
  validates :vat_rate, numericality: { only_integer: true }, allow_nil: true
end
