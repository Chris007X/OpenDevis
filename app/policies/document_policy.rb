class DocumentPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    record.project.user == user
  end

  def destroy?
    record.project.user == user
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:project).where(projects: { user: user })
    end
  end
end
