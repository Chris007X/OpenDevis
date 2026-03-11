module ArtisanDashboard
  class HomeController < BaseController
    def index
      @pending_requests = current_artisan.bidding_requests
                                         .where(status: "sent")
                                         .includes(:work_category, bidding_round: :project)
                                         .order("bidding_rounds.deadline ASC")
      @past_requests = current_artisan.bidding_requests
                                      .where(status: %w[responded declined expired replaced])
                                      .includes(:work_category, bidding_round: :project)
                                      .order(responded_at: :desc)
    end
  end
end
