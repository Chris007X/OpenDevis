module ApplicationHelper
  # ── SEO Defaults ──────────────────────────────────────────────────────
  DEFAULT_TITLE       = "OpenDevis — Devis de rénovation gratuit et instantané"
  DEFAULT_DESCRIPTION = "Estimez le coût de vos travaux de rénovation en quelques minutes. " \
                        "OpenDevis génère des devis détaillés par pièce, gratuit et sans inscription."
  DEFAULT_OG_IMAGE    = "og-image.png"
  SITE_URL            = "https://opendevis.com"

  def page_title
    content_for(:title).presence || DEFAULT_TITLE
  end

  def page_description
    content_for(:description).presence || DEFAULT_DESCRIPTION
  end

  def canonical_url
    content_for(:canonical).presence || request.original_url.split("?").first
  end

  # Returns an absolute URL to the OG image.
  # Override per-page: <% content_for :og_image, "my-custom-og.png" %>
  def og_image_url
    image = content_for(:og_image).presence || DEFAULT_OG_IMAGE
    image.start_with?("http") ? image : "#{SITE_URL}/#{image}"
  end

  # Optional meta keywords (low SEO weight, but some engines still use them).
  # Usage: <% content_for :keywords, "rénovation, devis, travaux" %>
  def page_keywords
    content_for(:keywords).presence
  end
end
