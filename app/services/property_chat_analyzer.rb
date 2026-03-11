require "net/http"
require "uri"

class PropertyChatAnalyzer
  ENDPOINT       = "https://models.inference.ai.azure.com/chat/completions"
  MODEL          = "gpt-4o-mini"
  REQUIRED_FIELDS = %w[type_de_bien total_surface_sqm room_count location_zip energy_rating].freeze

  def initialize(history)
    @history = history # Array of { role: "user"|"assistant", content: "..." }
  end

  def chat
    uri  = URI.parse(ENDPOINT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 20

    req = Net::HTTP::Post.new(uri.path)
    req["Authorization"] = "Bearer #{ENV.fetch('GITHUB_TOKEN')}"
    req["Content-Type"]  = "application/json"
    req.body = { model: MODEL, messages: [ { role: "system", content: system_prompt } ] + @history }.to_json

    res = http.request(req)
    raise "LLM error #{res.code}" unless res.is_a?(Net::HTTPSuccess)

    content = JSON.parse(res.body).dig("choices", 0, "message", "content").to_s
    parse_response(content)
  end

  private

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

  def system_prompt
    <<~PROMPT
      You are a friendly assistant helping collect information about a French real estate property for a renovation estimate.
      Your goal is to extract these 5 fields through conversation:
        - type_de_bien (property type in French: Appartement, Maison, Studio, Villa, Loft, etc.)
        - total_surface_sqm (decimal number)
        - room_count (integer)
        - location_zip (5-digit French postal code)
        - energy_rating (one of: A, B, C, D, E, F, G)

      Rules:
      - Always reply in French.
      - After each user message, extract what you can from the full conversation history.
      - If multiple fields are still missing, ask for ALL of them in a single friendly message (do not ask one by one).
      - If the user says they do not know a value for a field, set it to null.
      - Once all fields are known or null, end your reply with the separator ---DATA--- on its own line, followed by a JSON object.
      - The JSON must have exactly these keys: type_de_bien, total_surface_sqm, room_count, location_zip, energy_rating.
      - Do NOT include ---DATA--- until all 5 fields have been addressed.

      Example of a complete final response:
      Parfait, j'ai toutes les informations nécessaires ! Les champs ont été pré-remplis pour vous.
      ---DATA---
      {"type_de_bien":"Appartement","total_surface_sqm":65.0,"room_count":3,"location_zip":"75011","energy_rating":"D"}
    PROMPT
  end
end
