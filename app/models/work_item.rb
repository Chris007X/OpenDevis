class WorkItem < ApplicationRecord
  belongs_to :room
  belongs_to :work_category
  belongs_to :material

  validates :label, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price_exVAT, numericality: { greater_than_or_equal_to: 0 }
  validates :unit, presence: true

  after_save :update_project_totals
  after_destroy :update_project_totals

  private

  def update_project_totals
    room.project.recompute_totals!
  end
end
