module ArtisanDashboard
  class RequestsController < BaseController
    include ArtisanSubmission

    before_action :set_request, only: [:show, :submit_price, :decline]

    def index
      redirect_to artisan_dashboard_root_path
    end

    def show; end

    # rubocop:disable Metrics/MethodLength
    def submit_price
      if @bidding_request.status == "replaced"
        redirect_to artisan_dashboard_request_path(@bidding_request), alert: "Cette demande a été annulée."
        return
      end

      if @bidding_request.bidding_round.deadline_passed? && !@bidding_request.responded?
        redirect_to artisan_dashboard_request_path(@bidding_request), alert: "La date limite est dépassée."
        return
      end

      price = params[:price_total].to_f
      if price <= 0
        @error = "Veuillez entrer un prix valide."
        render :show and return
      end

      @bidding_request.update!(
        status: "responded",
        price_total: price,
        artisan_comment: params[:artisan_comment].to_s.strip.presence,
        responded_at: Time.current,
        response_method: "dashboard"
      )

      round = @bidding_request.bidding_round
      round.update!(status: "in_progress") if round.status == "sent"

      notify_artisan_responded(@bidding_request)
      redirect_to artisan_dashboard_request_path(@bidding_request), notice: "Votre devis a été envoyé."
    end
    # rubocop:enable Metrics/MethodLength

    def decline
      if @bidding_request.status == "replaced"
        redirect_to artisan_dashboard_request_path(@bidding_request), alert: "Cette demande a été annulée."
        return
      end

      @bidding_request.update!(status: "declined", responded_at: Time.current, response_method: "dashboard")
      notify_artisan_responded(@bidding_request)
      redirect_to artisan_dashboard_root_path, notice: "Demande déclinée."
    end

    private

    def set_request
      @bidding_request = current_artisan.bidding_requests
                                        .includes(:work_category, bidding_round: :project)
                                        .find(params[:id])
    end
  end
end
