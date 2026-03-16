class PropertyChatAnalyzer
  include LlmClient

  REQUIRED_FIELDS = %w[type_de_bien total_surface_sqm room_count location_zip energy_rating].freeze

  def initialize(history)
    @history = sanitize_history(history)
  end

  def chat
    messages = [{ role: "system", content: system_prompt }] + @history
    parse_response(fetch_llm_content(messages))
  end

  private

  def sanitize_history(raw)
    return [] unless raw.is_a?(Array)

    raw.first(20).filter_map do |msg|
      next unless msg.is_a?(Hash)

      role    = msg["role"].to_s
      content = msg["content"].to_s.strip
      next unless %w[user assistant].include?(role) && content.present?

      { role: role, content: content.first(2000) }
    end
  end

  # rubocop:disable Metrics/MethodLength
  def parse_response(content)
    if content.include?("---DATA---")
      parts    = content.split("---DATA---", 2)
      reply    = parts[0].strip
      json_str = parts[1].to_s.strip
      data     = JSON.parse(json_str)
      complete = REQUIRED_FIELDS.all? { |f| data[f].present? }
      { reply: reply, data: data, complete: complete }
    else
      { reply: content.strip, data: {}, complete: false }
    end
  rescue JSON::ParserError
    { reply: content.strip, data: {}, complete: false }
  end
  # rubocop:enable Metrics/MethodLength

  def system_prompt
    <<~PROMPT
      You are a concise, professional assistant collecting property information for a French renovation estimate.
      Your goal is to gather exactly 5 pieces of information:
        - Property type (Appartement, Maison, Studio, Villa, Loft, etc.)
        - Total surface area in square meters
        - Number of rooms
        - French postal code (5 digits)
        - DPE energy rating (A, B, C, D, E, F or G)

      Rules:
      - Reply in French. Be brief and professional — one or two sentences maximum per reply.
      - Use "vous" throughout. No exclamation marks, no filler phrases.
      - NEVER mention field names or technical labels (no "type_de_bien", "total_surface_sqm", etc.).
      - After each message, identify what is still missing and ask for ALL missing items in a single concise sentence.
      - If the user does not know a value, accept null and move on.
      - Do NOT summarise what you already know unless the user asks.
      - Once all 5 fields have been addressed (known or null), append ---DATA--- on its own line followed by a compact JSON object.
      - The JSON must have exactly these keys: type_de_bien, total_surface_sqm, room_count, location_zip, energy_rating, summary.
      - summary: a single professional sentence in French summarising the property based on what is known (e.g. "Appartement de 65 m² avec 3 pièces dans le 11e arrondissement de Paris, classé DPE D."). Omit null fields from the sentence.
      - Do NOT include ---DATA--- until all 5 fields have been addressed.

      Example of a complete final response:
      Les informations ont été enregistrées, vous pouvez les vérifier et les corriger si nécessaire.
      ---DATA---
      {"type_de_bien":"Appartement","total_surface_sqm":65.0,"room_count":3,"location_zip":"75011","energy_rating":"D","summary":"Appartement de 65 m² avec 3 pièces dans le 11e arrondissement de Paris, classé DPE D."}
    PROMPT
  end
end
