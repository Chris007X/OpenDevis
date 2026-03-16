require "net/http"
require "uri"

module LlmClient
  ENDPOINT = "https://models.inference.ai.azure.com/chat/completions"
  MODEL = "gpt-4o-mini"

  private

  # Returns raw content string — use when response is not plain JSON (e.g. custom delimiters)
  # rubocop:disable Metrics/MethodLength
  def fetch_llm_content(messages)
    uri  = URI.parse(ENDPOINT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.read_timeout = 20

    req = Net::HTTP::Post.new(uri.path)
    req["Authorization"] = "Bearer #{ENV.fetch('GITHUB_TOKEN')}"
    req["Content-Type"]  = "application/json"
    req.body = { model: MODEL, messages: messages }.to_json

    res = http.request(req)
    raise "LLM error #{res.code}" unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body).dig("choices", 0, "message", "content").to_s
  end
  # rubocop:enable Metrics/MethodLength

  # Calls the LLM and parses the response as JSON
  def query_llm(messages)
    extract_json(fetch_llm_content(messages))
  end

  def extract_json(content)
    json_str = content[/```json\s*(.*?)\s*```/m, 1] || content[/\{.*\}/m]
    return {} unless json_str

    JSON.parse(json_str)
  rescue JSON::ParserError
    {}
  end
end
