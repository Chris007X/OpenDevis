class ArtisanPortalPolicy < ApplicationPolicy
  # Token-based access — no auth required
  def show?
    true
  end

  def submit?
    true
  end
end
