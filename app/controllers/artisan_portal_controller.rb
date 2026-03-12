class ArtisanPortalController < ApplicationController
  include ArtisanSubmission

  skip_before_action :authenticate_user!
  before_action :set_bidding_request
  layout "artisan_portal"

  def show
    skip_authorization
  end

  # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
  def submit
    skip_authorization

    if @bidding_request.status == "replaced"
      redirect_to artisan_portal_path(@bidding_request.token), alert: "Cette demande a été annulée."
      return
    end

    if @bidding_request.bidding_round.deadline_passed? && !@bidding_request.responded?
      redirect_to artisan_portal_path(@bidding_request.token), alert: "La date limite est dépassée."
      return
    end

    if params[:decline].present?
      @bidding_request.update!(status: "declined", responded_at: Time.current, response_method: "web")
    else
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
        response_method: "web"
      )

      round = @bidding_request.bidding_round
      round.update!(status: "in_progress") if round.status == "sent"
    end

    notify_artisan_responded(@bidding_request)
    redirect_to artisan_portal_path(@bidding_request.token), notice: "Votre réponse a été enregistrée."
  end
  # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity

  private

  def set_bidding_request
    @bidding_request = BiddingRequest.find_by!(token: params[:token])
  rescue ActiveRecord::RecordNotFound
    render plain: "Ce lien n'est pas valide.", status: :not_found
  end
end
