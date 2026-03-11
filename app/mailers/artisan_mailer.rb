class ArtisanMailer < ApplicationMailer
  # rubocop:disable Metrics/MethodLength
  def quote_request(bidding_request_id)
    @bidding_request = BiddingRequest.includes(:artisan, :work_category, bidding_round: { project: :rooms })
                                     .find(bidding_request_id)
    @artisan = @bidding_request.artisan
    @work_category = @bidding_request.work_category
    @project = @bidding_request.bidding_round.project
    @round = @bidding_request.bidding_round
    @portal_url = artisan_portal_url(@bidding_request.token)

    @category_estimate = @project.rooms.joins(work_items: :work_category)
                                 .where(work_items: { standing_level: @round.standing_level,
                                                      work_category_id: @work_category.id })
                                 .sum("work_items.quantity * work_items.unit_price_exVAT")

    mail(
      to: @artisan.email,
      subject: "Demande de devis — #{@work_category.name} — #{@project.location_zip}",
      reply_to: "devis+#{@bidding_request.token}@inbound.opendevis.com"
    )
  end
  # rubocop:enable Metrics/MethodLength
end
