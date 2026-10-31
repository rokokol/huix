let
  # One cheap model serves every background job, so a change of it is a change in one line
  background = "z-ai/glm-5.3-flash";
in
{
  chat = {
    "deepseek/deepseek-v4.1-flash-1017" = [
      "deepinfra/fp8"
      "morph/fp8"
    ];
    "z-ai/glm-5.3" = [
      "morph/fp8"
      "sail-research/fp8"
    ];
    ${background} = [
      "near-ai/fp8"
      "morph/fp8"
    ];
  };
  memory = {
    model = background;
    # OpenRouter list prices per token, checked 2026-10-31; update both when the model changes
    price = {
      input = 0.0000000163;
      output = 0.0000001479;
    };
  };
  side = {
    model = background;
    # pi addresses a model as provider/id, and both side agents take this one
    piModel = "openrouter/${background}";
  };
  embeddings = {
    model = "qwen/qwen3-embedding-8b";
    dimensions = 1024;
  };
  stt.model = "microsoft/mai-transcribe-2";
  reranker = {
    # OpenRouter's ZDR guardrail excludes every external rerank endpoint, so keep the
    # fusion-only reranker until a ZDR-capable one exists (local, or the guardrail changes)
    provider = "rrf";
    # Kept for the switch back once an endpoint passes the guardrail
    model = "voyageai/rerank-2.5-lite";
    maxCandidates = 100;
    maxTokensPerCandidate = 512;
  };
}
