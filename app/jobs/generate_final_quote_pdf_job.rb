class GenerateFinalQuotePdfJob < ApplicationJob
  queue_as :default

  def perform(bidding_round_id)
    # Phase 3: generate PDF for final quote
    Rails.logger.info "[GenerateFinalQuotePdfJob] bidding_round #{bidding_round_id} (Phase 3 not yet implemented)"
  end
end
