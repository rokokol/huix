let
  # One cheap model serves every background job, so a change of it is a change in one line
  background = "z-ai/glm-5.3-flash";
in
{
  chat = {
    # Host order per model, primary first. This map is the single source: the Hermes
    # module derives provider_routing from it, and pi's hoster guard reads it directly.
    "deepseek/deepseek-v4.1-flash" = [
      "morph/fp8"
      "deepinfra/fp8"
    ];
    "z-ai/glm-5.3" = [
      "morph/fp8"
      "sail-research/fp8"
    ];
    # near-ai leads on the cache-read price ($0.012/M against $0.02 at open-inference),
    # and a recall-heavy day is ~97% cache, so it is the cheapest fp8 host by $0.27/day;
    # open-inference is fp4 and dearer on that profile, darkbloom is fp4 alone.
    ${background} = [
      "near-ai/fp8"
      "morph/fp8"
    ];
  };
  memory = {
    model = background;
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
  reranker = {
    provider = "openrouter";
    model = "mongodb/rerank-3";
    # A provider failure falls back to fusion so that recall still returns results
    fallback = "rrf";
    maxCandidates = 100;
    maxTokensPerCandidate = 512;
  };
}
