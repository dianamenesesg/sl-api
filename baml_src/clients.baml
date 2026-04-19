// Classification: zero temperature — one correct theme, no creative variation wanted
client<llm> ClassificationClient {
  provider openai-generic
  options {
    base_url "https://api.tokenfactory.nebius.com/v1/"
    api_key env.NEBIUS_API_KEY
    model "meta-llama/Meta-Llama-3.1-8B-Instruct"
    temperature 0
  }
}

// Extraction: default temperature — allows natural phrasing in extracted values
client<llm> ExtractionClient {
  provider openai-generic
  options {
    base_url "https://api.tokenfactory.nebius.com/v1/"
    api_key env.NEBIUS_API_KEY
    model "google/gemma-2-2b-it"
  }
}