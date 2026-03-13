module ApplicationHelper
  DEFAULT_TITLE = "OpenDevis — Devis de rénovation gratuit et instantané"
  DEFAULT_DESCRIPTION = "Estimez le coût de vos travaux de rénovation en quelques minutes. " \
                        "OpenDevis génère des devis détaillés par pièce, gratuit et sans inscription."

  def page_title
    content_for(:title).presence || DEFAULT_TITLE
  end

  def page_description
    content_for(:description).presence || DEFAULT_DESCRIPTION
  end

  def canonical_url
    request.original_url.split("?").first
  end
end
