class ArtisanCategory < ApplicationRecord
  belongs_to :artisan
  belongs_to :work_category

  validates :artisan_id, uniqueness: { scope: :work_category_id }
end
