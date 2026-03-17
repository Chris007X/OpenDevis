class TestRun < ApplicationRecord
  validates :ran_at, presence: true

  scope :recent, ->(n = 50) { order(ran_at: :desc).limit(n) }

  def pass_rate
    total = pages_total + flows_total + ui_total
    return nil if total.zero?

    ((pages_passed + flows_passed + ui_passed).to_f / total * 100).round(1)
  end

  def overall_passed?
    errors_count.zero? &&
      pages_passed == pages_total &&
      flows_passed == flows_total &&
      ui_passed    == ui_total
  end
end
