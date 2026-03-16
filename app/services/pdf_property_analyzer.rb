class PdfPropertyAnalyzer
  include LlmClient

  MAX_TEXT_LENGTH = 8000

  def initialize(tempfile)
    @tempfile = tempfile
  end

  def analyze
    text = extract_text
    raise "Le document ne contient pas de texte lisible." if text.blank?

    messages = [
      { role: "system", content: system_prompt },
      { role: "user", content: "Document content:\n\n#{text}" }
    ]
    query_llm(messages)
  end

  private

  def extract_text
    reader = PDF::Reader.new(@tempfile)
    reader.pages.map(&:text).join("\n").gsub(/\s+/, " ").strip.first(MAX_TEXT_LENGTH)
  rescue PDF::Reader::MalformedPDFError
    raise "Le fichier PDF est corrompu ou illisible."
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
