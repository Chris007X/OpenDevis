class WorkItemPolicy < ApplicationPolicy
  def create?
    record.room.project.user == user
  end

  def update?
    record.room.project.user == user
  end

  def destroy?
    record.room.project.user == user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(room: :project).where(projects: { user: user })
    end
  end
end
