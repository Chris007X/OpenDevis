class WorkCategory < ApplicationRecord
   # Associations
   has_many :work_items
   has_many :materials
   
   # Validations
  validates :name, presence: true, length: { minimum: 2 }
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_-]+\z/ }

  # Petit bonus : s'assurer que le slug est toujours en minuscules avant la sauvegarde
  before_validation :lowercase_slug

  private

  def lowercase_slug
    self.slug = slug.downcase if slug.present?
  end
end
