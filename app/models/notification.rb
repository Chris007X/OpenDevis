class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :project, optional: true

  KINDS = %w[artisan_responded all_responded final_quote_ready manual_review].freeze

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :title, presence: true

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc) }
end
