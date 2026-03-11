class BiddingRoundPolicy < ApplicationPolicy
  def new?
    user.present? && record_project_owner?
  end

  def create?
    new?
  end

  def show?
    new?
  end

  def send_requests?
    new?
  end

  def select_artisans?
    new?
  end

  def update_artisans?
    new?
  end

  def review_responses?
    new?
  end

  def confirm_selections?
    new?
  end

  def final_quote?
    new?
  end

  def select_replacement?
    new?
  end

  def replace_artisan?
    new?
  end

  private

  def record_project_owner?
    if record.is_a?(BiddingRound)
      record.project.user == user
    else
      record == :bidding_round
    end
  end
end
