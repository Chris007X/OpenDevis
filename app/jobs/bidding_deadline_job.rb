class BiddingDeadlineJob < ApplicationJob
  queue_as :default

  def perform(bidding_round_id)
    round = BiddingRound.find_by(id: bidding_round_id)
    return unless round&.deadline_passed?

    round.bidding_requests.where(status: "sent").find_each { |req| req.update!(status: "expired") }

    Notification.create!(
      user: round.project.user,
      project: round.project,
      kind: "all_responded",
      title: "Date limite atteinte — #{round.project.location_zip}",
      body: "Le délai de réponse est passé. Vous pouvez maintenant consulter les recommandations."
    )
  end
end
