require "net/http"
require "uri"

class PdfPropertyAnalyzer
  ENDPOINT        = "https://models.inference.ai.azure.com/chat/completions"
  MODEL           = "gpt-4o-mini"
  MAX_TEXT_LENGTH = 8000

  def initialize(tempfile)
    @tempfile = tempfile
  end

  def analyze
    text = extract_text
    raise "Le document ne contient pas de texte lisible." if text.blank?

    query_llm(text)
  end

  private

  def extract_text
    reader = PDF::Reader.new(@tempfile)
    reader.pages.map(&:text).join("\n").gsub(/\s+/, " ").strip.first(MAX_TEXT_LENGTH)
  rescue PDF::Reader::MalformedPDFError
    raise "Le fichier PDF est corrompu ou illisible."
  end

  def query_llm(text)
    uri  = URI.parse(ENDPOINT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 20

    req = Net::HTTP::Post.new(uri.path)
    req["Authorization"] = "Bearer #{ENV.fetch('GITHUB_TOKEN')}"
    req["Content-Type"]  = "application/json"
    req.body = {
      model: MODEL,
      messages: [
        { role: "system", content: system_prompt },
        { role: "user",   content: "Document content:\n\n#{text}" }
      ]
    }.to_json

    res = http.request(req)
    raise "LLM error #{res.code}" unless res.is_a?(Net::HTTPSuccess)

    content = JSON.parse(res.body).dig("choices", 0, "message", "content").to_s
    extract_json(content)
  end

  def extract_json(content)
    json_str = content[/```json\s*(.*?)\s*```/m, 1] || content[/\{.*\}/m]
    return {} unless json_str

    JSON.parse(json_str)
  rescue JSON::ParserError
    {}
  end

  def system_prompt
    <<~PROMPT
      You are a helpful assistant specialized in French real estate documents.
      Given the text content of a document (property listing, diagnostic report, or deed),
      extract the following fields and return them as a JSON object:

      - type_de_bien: property type in French (Appartement, Maison, Studio, Villa, Loft, etc.)
      - total_surface_sqm: total surface area in square meters as a decimal number
      - room_count: number of rooms as an integer
      - location_zip: French postal code as a 5-digit string
      - energy_rating: DPE energy class, one letter among A, B, C, D, E, F or G
      - summary: a single professional sentence in French summarising the property (e.g. "Maison de 120 m² avec 5 pièces à Lyon, classée DPE C."). Only include fields that are present; omit null fields from the sentence.

      Set any field to null if the information is not present.
      Return only the JSON object, with no additional text.
    PROMPT
  end
end
