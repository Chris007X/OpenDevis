class Document < ApplicationRecord
  belongs_to :project

  validates :file_name, presence: true
  validates :file_url, presence: true
end
