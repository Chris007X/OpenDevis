class Artisan < ApplicationRecord
  devise :database_authenticatable, :recoverable, :rememberable, :validatable

  has_many :artisan_categories, dependent: :destroy
  has_many :work_categories, through: :artisan_categories
  has_many :bidding_requests, dependent: :destroy

  validates :name, :postcode, presence: true
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :for_postcode, ->(zip) { where("LEFT(postcode, 2) = ?", zip.to_s.first(2)) if zip.present? }
  scope :for_category, lambda { |category_id|
    joins(:artisan_categories).where(artisan_categories: { work_category_id: category_id })
  }
  scope :for_project, ->(project) { active.for_postcode(project.location_zip) }

  def star_rating
    return 0 unless rating

    rating.round(1)
  end
end
