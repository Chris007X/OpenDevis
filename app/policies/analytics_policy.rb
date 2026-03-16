class AnalyticsPolicy < ApplicationPolicy
  # The analytics endpoint is open to everyone (anonymous + authenticated).
  def create?
    true
  end
end
