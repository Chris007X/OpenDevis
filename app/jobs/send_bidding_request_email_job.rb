class SendBiddingRequestEmailJob < ApplicationJob
  queue_as :default

  def perform(bidding_request_id)
    request = BiddingRequest.find_by(id: bidding_request_id)
    return unless request

    ArtisanMailer.quote_request(request.id).deliver_now
  end
end
