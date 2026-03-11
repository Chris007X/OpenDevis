class ProcessInboundEmailJob < ApplicationJob
  queue_as :default

  def perform(_payload)
    # Phase 2: Parse inbound email reply and update BiddingRequest
    # Extract token from To: address (devis+TOKEN@inbound.opendevis.com)
    # Use Claude API to extract price from email body
    Rails.logger.info "[ProcessInboundEmailJob] Received inbound email payload (Phase 2 not yet implemented)"
  end
end
