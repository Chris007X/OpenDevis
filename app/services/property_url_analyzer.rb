require "net/http"
require "uri"

class PropertyUrlAnalyzer
  GITHUB_MODELS_ENDPOINT = "https://models.inference.ai.azure.com/chat/completions"
  MODEL = "gpt-4o-mini"
  MAX_TEXT_LENGTH = 8000

  def initialize(url)
    @url = url
  end

  def analyze
    html = fetch_html
    text = extract_text(html)
    query_llm(text)
  end

  private

  BROWSER_HEADERS = {
    "User-Agent"      => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept"          => "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
    "Accept-Language" => "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7",
    "Accept-Encoding" => "identity",
    "DNT"             => "1",
    "Connection"      => "keep-alive",
    "Upgrade-Insecure-Requests" => "1",
    "Sec-Fetch-Dest"  => "document",
    "Sec-Fetch-Mode"  => "navigate",
    "Sec-Fetch-Site"  => "none",
    "Sec-Fetch-User"  => "?1"
  }.freeze

  def fetch_html
    conn = Faraday.new do |f|
      f.options.timeout = 15
      BROWSER_HEADERS.each { |k, v| f.headers[k] = v }
    end
    response = conn.get(@url)
    raise "HTTP #{response.status}" unless response.success?

    response.body
  end

  def extract_text(html)
    doc = Nokogiri::HTML(html)
    doc.search("script, style, nav, footer, header, iframe").remove
    doc.text.gsub(/\s+/, " ").strip.first(MAX_TEXT_LENGTH)
  end

  def query_llm(text)
    uri = URI.parse(GITHUB_MODELS_ENDPOINT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 20

    request = Net::HTTP::Post.new(uri.path)
    request["Authorization"] = "Bearer #{ENV.fetch('GITHUB_TOKEN')}"
    request["Content-Type"] = "application/json"
    request.body = {
      model: MODEL,
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: "Voici le texte de l'annonce immobilière :\n\n#{text}" }
      ]
    }.to_json

    response = http.request(request)
    raise "LLM API error #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

    content = JSON.parse(response.body).dig("choices", 0, "message", "content").to_s
    extract_json(content)
  end

  def extract_json(content)
    # Handle markdown code blocks (```json ... ```) and plain JSON
    json_str = content[/```json\s*(.*?)\s*```/m, 1] || content[/\{.*\}/m]
    return {} unless json_str

    JSON.parse(json_str)
  rescue JSON::ParserError
    {}
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
