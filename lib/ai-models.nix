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
    "z-ai/glm-5.3-flash" = [
      "near-ai/fp8"
      "morph/fp8"
    ];
  };
  memory.model = "z-ai/glm-5.3-flash";
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
