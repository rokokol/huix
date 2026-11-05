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

## Hindsight spends an OpenRouter key of its own

**Where:** `lib/ai-models.nix` (`memory`, `reranker`), `nixos/services/ai/hindsight/service.nix` (`hindsight.env` and the service environment) and `nixos/services/ai/hindsight/monitor.nix`

**Why it differs from the obvious route:** one OpenRouter key serves every model, and the spend is then estimated from the token counters of each consumer. For Hindsight that estimate cannot be built: its model calls, embeddings and rerank keep no token count a price could multiply, and the catalog prices the rerank model at zero (see `PITFALLS.md`, "A rerank model's catalog entry says its price is zero"). A key of its own makes the counter of `openrouter-hindsight-api-key` the spend as the provider billed it, covering chat, embeddings and rerank together, with no price kept by hand in the flake and no patch to a package nixpkgs owns. It also confines Hindsight's limit and revocation: an exhausted budget or a leaked key does not touch the agents' key, and the reverse holds too

**What returning to the obvious route breaks:** the shared counter mixes Hindsight with Hermes and pi, so the Hindsight panels either show a share of one number or fall back to a per-token estimate that no counter supports; a hand-kept price then decides the figure, and a model change leaves it silently wrong

**Rejected alternative:** keeping the estimate and a price table beside the model name. It reads as exact while it ignores cache discounts, embeddings and rerank, and it charges the wrong model the moment `memory.model` moves

**Enforcement:** `scripts/tests/test-hindsight-config.py` requires all three model keys of `hindsight.env` to carry one placeholder other than the agents' key, and `scripts/tests/test-hindsight-spend-monitor.py` pins what the counter exports
