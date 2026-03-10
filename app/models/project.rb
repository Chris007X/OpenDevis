class Project < ApplicationRecord
  belongs_to :user
  has_many :rooms, dependent: :destroy
  has_many :documents, dependent: :destroy
  # Optionnel : permet d'accéder directement aux travaux via le projet
  has_many :work_items, through: :rooms
end
