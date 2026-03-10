class Room < ApplicationRecord
  belongs_to :project
  has_many :work_items, dependent: :destroy

  validates :name, presence: true
  validates :surface_sqm, numericality: { greater_than: 0 }, allow_nil: true
  validates :perimeter_lm, numericality: { greater_than: 0 }, allow_nil: true
  validates :wall_height_m, numericality: { greater_than: 0 }, allow_nil: true
end
