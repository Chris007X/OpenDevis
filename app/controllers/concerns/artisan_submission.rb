module ArtisanSubmission
  extend ActiveSupport::Concern

  private

  def notify_artisan_responded(bidding_request)
    project = bidding_request.bidding_round.project
    price_text = bidding_request.price_total.present? ? "#{bidding_request.price_total} € HT" : "Décliné"

    Notification.create!(
      user: project.user,
      project: project,
      kind: "artisan_responded",
      title: "#{bidding_request.artisan.name} a répondu",
      body: "#{bidding_request.work_category.name} — #{price_text}"
    )

    check_all_resolved(bidding_request.bidding_round)
  end

  def check_all_resolved(bidding_round)
    active = bidding_round.bidding_requests.where.not(status: "replaced")
    return if active.where(status: "sent").exists?

    Notification.create!(
      user: bidding_round.project.user,
      project: bidding_round.project,
      kind: "all_responded",
      title: "Toutes les réponses reçues",
      body: "Vous pouvez maintenant consulter les recommandations."
    )
  end
end
