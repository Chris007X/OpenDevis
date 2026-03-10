class WorkCategory < ApplicationRecord
  has_many :materials, dependent: :destroy
  has_many :work_items

  validates :name, presence: true
end
