class WorkCategory < ApplicationRecord
  has_many :materials, dependent: :destroy
  has_many :work_items
  has_many :artisan_categories, dependent: :destroy
  has_many :artisans, through: :artisan_categories

  validates :name, presence: true
end
