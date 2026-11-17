# Deviations

Permanent cross-cutting choices in this flake that differ from the obvious arrangement. Each entry preserves why the choice cannot move to a narrower layer and what breaks without it. An arrangement that an upstream change could retire belongs in `WORKAROUNDS.md`, and a trap that reports a plausible success belongs in `PITFALLS.md`

---

## The root holds every `ddlc-palette` input to one node

**Where:** `flake.nix` — every `ddlc-*` input carries `inputs.ddlc-palette.follows = "ddlc-palette";` next to the `nixpkgs` one

**Why it differs from the obvious route:** `follows` rewrites an input's own dependency tree, and only the flake that owns that tree may declare it. A child repository can make its `nixpkgs` follow its input, but it cannot make its `ddlc-palette` resolve to a node in whoever consumes it — that node does not exist from where the child is written. This is not a gap to close in the children; the declarations at the root are the mechanism

**What returning to the obvious route breaks:** an input without the line pulls its own copy of the palette and the lock holds a suffixed second node. The lock once held five at four revisions (`ddlc-rofi-theme` on `6a2277a`, `ddlc-sddm-theme` on `68eedcf`, two on `7b7300d`, root on its own). A colour corrected in the palette then reaches whichever theme was bumped and leaves the rest on the old hex, defeating the single source of truth invisibly unless somebody reads the lock

**Enforcement:** CI asks the lock for every node whose name starts with `ddlc-palette`

```sh
python3 -c "import json;print([k for k in json.load(open('flake.lock'))['nodes'] if k.startswith('ddlc-palette')])"
```

Anything but `['ddlc-palette']` means a parent is missing its `follows`

---

## Hindsight's models split between the Go subscription and an OpenRouter key

**Where:** `lib/ai-models.nix` (`memory`, `reranker`), `nixos/services/ai/hindsight/service.nix` (`hindsight.env` and the service environment) and `nixos/services/ai/hindsight/monitor.nix`

**Why it differs from the obvious route:** one OpenRouter key for everything was the plain arrangement, and the memory LLM alone spent about $0.48 a day against a key whose ceiling is $5 — a bill that kept arriving at its limit. The Go subscription carries the same traffic for roughly 0.6 points of its monthly window a day (measured 18 November 2026: 4 points of the 5-hour window cost $0.52 of allowance, and that window is a fifth of a month worth about $100 of list price). Go answers 404 on embeddings and on rerank, so those two stay on the key, which is also why the key cannot be dropped

**What returning to the obvious route breaks:** the memory LLM back on the key restores the $0.48 a day against a $5 ceiling. Moving embeddings or the reranker to Go does not run at all. Reading the key's counter as the whole of Hindsight's spend now undercounts it by the LLM's share, which lives in the Go windows and nowhere else — the panels say so where the counter is exported, and `HINDSIGHT_API_LLM_EXTRA_BODY` must not be sent to Go: the `provider {order, only, zdr}` block in it is OpenRouter's own

**Rejected alternative:** keeping the estimate and a price table beside the model name. It reads as exact while it ignores cache discounts, embeddings and rerank, and it charges the wrong model the moment `memory.model` moves

**Enforcement:** `scripts/tests/test-hindsight-config.py` requires the LLM key of `hindsight.env` to carry the Go placeholder while embeddings and the reranker carry one other placeholder different from the agents' key, requires the provider, the bare model name, an explicit reasoning effort and no base URL or extra body, and `scripts/tests/test-hindsight-monitor.py` pins what the counter exports, including a day that grows and a trace read that fails
