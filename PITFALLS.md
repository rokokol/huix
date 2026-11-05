# Pitfalls

Traps in the tools and services this flake drives. Each entry preserves how to reproduce it, what the reader sees instead of the truth, and the way through. A shortcut that a fixed version retires belongs in `WORKAROUNDS.md`, and a permanent choice that differs from the obvious arrangement in `DEVIATIONS.md`

---

## A rerank model's catalog entry says its price is zero

**Where it bites:** wherever a price or a token count for OpenRouter is read — `lib/ai-models.nix`, the Spend row of `nixos/services/system/grafana/dashboards/hindsight.nix`, and any script that bills a call whose role is not chat

**Reproduction:** `qwen/qwen3-reranker-8b`, checked on 5 November 2026

```sh
curl -s 'https://openrouter.ai/api/v1/models?output_modalities=rerank' \
  | jq '.data[] | select(.id == "qwen/qwen3-reranker-8b") | .pricing'
curl -s 'https://openrouter.ai/api/v1/models/qwen/qwen3-reranker-8b/endpoints' \
  | jq '.data.endpoints[] | .pricing'
```

Both answer `{"prompt": "0", "completion": "0"}` for the model and for its Fireworks endpoint, while one live rerank call of a query and two documents answered `"usage": {"total_tokens": 160, "cost": 0.000032}`

**Misleading result:** the zeros read as a free model, so a panel multiplies a token count by zero and shows a confident `$0.00`, and a budget check never fires

**Mechanism:** `prompt` and `completion` are chat-completion prices. A rerank endpoint bills input tokens alone and states what it charged in `usage.cost` of the response, which neither catalog field carries. Hindsight then reads `results[].index` and `relevance_score` out of that response and drops `usage`, so the one exact number the provider sends reaches neither Prometheus nor the `llm_requests` table

**Safe route:** take the cost from the response or from the counter of the key that pays, never from the catalog. `GET /key` reports it exactly, which is what Hindsight's own key exists for — see `DEVIATIONS.md`, "Hindsight spends an OpenRouter key of its own". The same response also shows why tokens cannot stand in for money here: an embedding or rerank call bills input tokens alone, while its `llm_tokens_output_tokens_total` stays empty, so a panel that multiplies stored tokens by a price undercounts precisely the calls whose price is hardest to know
