let
  # One cheap model serves every background job, so a change of it is a change in one line
  background = "deepseek/deepseek-v4.1-flash";
in
{
  chat = {
    # Host order per model, primary first. This map is the single source: the Hermes
    # module derives provider_routing from it, and pi's hoster guard reads it directly.
    ${background} = [
      "deepinfra/fp8"
      "coreweave/fp8"
    ];
  };
  memory = {
    # Measured 2026-11-13 against the bank's own prompts: GLM-5.3-Flash returns 2-3 facts
    # where this model returns 10-20 on the same chunk, while "none" reasoning keeps it
    # faster and cheaper than GLM and still returns valid JSON in Russian
    model = background;
    # The Go API names a model without its vendor, the way `side.piModel` does
    goModel = "deepseek-v4.1-flash";
  };
  side = {
    # Hermes reaches this model through OpenRouter, whose routing this flake configures
    model = background;
    # The pi side agents go through opencode-go, which names a model without its vendor
    piModel = "opencode-go/glm-5.3-flash";
  };
  embeddings = {
    model = "qwen/qwen3-embedding-8b";
    dimensions = 1024;
  };
  stt.model = "microsoft/mai-transcribe-2";
  tts.model = "mistralai/voxtral-mini-tts-3-0";
  reranker = {
    provider = "openrouter";
    model = "mongodb/rerank-3-lite";
    # A provider failure falls back to fusion so that recall still returns results
    fallback = "rrf";
    maxCandidates = 100;
    maxTokensPerCandidate = 512;
  };
}
