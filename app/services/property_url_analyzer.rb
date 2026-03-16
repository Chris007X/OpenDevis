require "resolv"

class PropertyUrlAnalyzer
  include LlmClient

  MAX_TEXT_LENGTH = 8000

  BROWSER_HEADERS = {
    "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language" => "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7",
    "Accept-Encoding" => "identity",
    "DNT" => "1",
    "Connection" => "keep-alive",
    "Upgrade-Insecure-Requests" => "1",
    "Sec-Fetch-Dest" => "document",
    "Sec-Fetch-Mode" => "navigate",
    "Sec-Fetch-Site" => "none",
    "Sec-Fetch-User" => "?1"
  }.freeze

  ALLOWED_SCHEMES = %w[http https].freeze
  BLOCKED_IP_RANGES = [
    /\A127\./, # loopback
    /\A10\./, # RFC1918
    /\A172\.(1[6-9]|2\d|3[01])\./, # RFC1918
    /\A192\.168\./, # RFC1918
    /\A169\.254\./, # AWS/GCP/Azure metadata
    /\A::1\z/, # IPv6 loopback
    /\Afc00:/i, # IPv6 ULA
    /\Afd/i # IPv6 ULA
  ].freeze

  def initialize(url)
    @url = url
  end

  def analyze
    html   = fetch_html
    doc    = Nokogiri::HTML(html)
    photo  = extract_photo(doc)
    text   = extract_text_from_doc(doc)
    result = query_llm_for_listing(text)
    result["photo_url"] = photo if photo
    result
  end

  private

  def validate_url!
    uri = URI.parse(@url)
    raise ArgumentError, "URL invalide" unless ALLOWED_SCHEMES.include?(uri.scheme)
    raise ArgumentError, "URL invalide" if uri.host.blank?

    ip = Resolv.getaddress(uri.host)
    raise ArgumentError, "URL non autorisée" if BLOCKED_IP_RANGES.any? { |p| ip.match?(p) }
  rescue URI::InvalidURIError
    raise ArgumentError, "URL invalide"
  rescue Resolv::ResolvError
    raise ArgumentError, "Hôte introuvable"
  end

  def fetch_html
    validate_url!
    conn = Faraday.new do |f|
      f.options.timeout = 15
      BROWSER_HEADERS.each { |k, v| f.headers[k] = v }
    end
    response = conn.get(@url)
    raise "HTTP #{response.status}" unless response.success?

    response.body
  end

  # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
  def extract_photo(doc)
    url = doc.at('meta[property="og:image"]')&.[]("content") ||
          doc.at('meta[name="twitter:image"]')&.[]("content") ||
          doc.css("img[src]").find do |img|
            img["src"].to_s.match?(/\.(jpg|jpeg|png|webp)/i) &&
              !img["src"].to_s.match?(/logo|icon|sprite|avatar|placeholder/i)
          end&.[]("src")
    return nil unless url.present?
    return url if url.start_with?("http")

    URI.join(@url, url).to_s
  rescue URI::InvalidURIError
    nil
  end
  # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity

  def extract_text_from_doc(doc)
    doc = doc.dup
    doc.search("script, style, nav, footer, header, iframe").remove
    doc.text.gsub(/\s+/, " ").strip.first(MAX_TEXT_LENGTH)
  end

  def query_llm_for_listing(text)
    messages = [
      { role: "system", content: system_prompt },
      { role: "user", content: "Voici le texte de l'annonce immobilière :\n\n#{text}" }
    ]
    query_llm(messages)
  end

  def system_prompt
    <<~PROMPT
      You are a helpful assistant specialized in French real estate listings.
      When given the text of a property listing, extract the following fields and return them as a JSON object:

      - type_de_bien: the property type in French (e.g. Appartement, Maison, Studio, Villa, Loft)
      - total_surface_sqm: the total surface area in square meters as a decimal number
      - room_count: the number of rooms as an integer
      - location_zip: the French postal code as a 5-digit string
      - energy_rating: the DPE energy class, one letter among A, B, C, D, E, F or G
      - summary: a single professional sentence in French summarising the property (e.g. "Appartement de 65 m² avec 3 pièces situé dans le 11e arrondissement de Paris, classé DPE D."). Only include fields that are present; omit null fields from the sentence.

      Set any field to null if the information is not present in the text.
      Return only the JSON object, with no additional text.
    PROMPT
  end
end
