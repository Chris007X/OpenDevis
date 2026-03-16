class AnalyticsFunnel < ApplicationRecord
  validates :funnel_name, presence: true

  scope :by_funnel, ->(name) { where(funnel_name: name) }
  scope :recent, ->(days = 30) { where("created_at > ?", days.days.ago) }
  scope :completed, -> { where(completed: true) }

  # Returns step-by-step completion rates for a named funnel
  # { step_number => { step_name:, entered:, completed:, rate: } }
  def self.completion_rates(funnel_name, days = 30)
    steps = by_funnel(funnel_name).recent(days).group(:step_number, :step_name).count

    steps.each_with_object({}) do |((step_num, step_name), entered_count), result|
      completed_count = by_funnel(funnel_name).recent(days)
                                              .where(step_number: step_num, completed: true)
                                              .count
      result[step_num] = {
        step_name: step_name,
        entered: entered_count,
        completed: completed_count,
        rate: entered_count.zero? ? 0.0 : (completed_count.to_f / entered_count * 100).round(2)
      }
    end.sort.to_h
  end

  # Overall funnel conversion: users who completed all steps vs. who started step 1
  def self.overall_conversion(funnel_name, days = 30)
    started = by_funnel(funnel_name).recent(days).where(step_number: 1).count
    return 0.0 if started.zero?

    max_step = by_funnel(funnel_name).maximum(:step_number)
    finished = by_funnel(funnel_name).recent(days).where(step_number: max_step, completed: true).count
    (finished.to_f / started * 100).round(2)
  end
end
