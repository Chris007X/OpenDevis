class NotificationPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  def mark_read?
    record.user == user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end
end
