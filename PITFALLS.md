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

---

## Hindsight's call counter records chat alone

**Where it bites:** any panel or query that counts model calls of Hindsight — `nixos/services/system/grafana/dashboards/hindsight.nix`

**Reproduction:** on Hindsight 1.1.0, run one recall of the shared bank and read the service's own metrics

```sh
curl -s http://127.0.0.1:8888/metrics | grep 'hindsight_llm_calls_total'
curl -s http://127.0.0.1:8888/metrics | grep 'phase="reranking"' | grep count
```

`hindsight_llm_calls_total` lists the chat and reflect scopes only and never carries `scope="rerank"`, however many recalls run, while the reranking phase counter rises by one per recall and takes seconds of wall time

**Misleading result:** the panel draws no line and reports no error. Prometheus accepts a selector that matches nothing, so a wrong label reads as "no reranking happened"

**Mechanism:** the cross-encoder traces its call through `trace_model_call` with `RERANK_SCOPE`, and that row lands in the bank's `llm_requests` table. The `hindsight_llm_calls_total` and `hindsight_llm_duration_seconds` counters are fed from the chat path alone, so the rerank call and the usage the provider returns reach neither

**Safe route:** `nixos/services/ai/hindsight/monitor.nix` exports observed model call traces for the configured bank. These include errors and do not prove payment or fallback. The phase histogram counts completed stages and covers a different scope, so subtracting traces cannot measure fallback. Read actual spend from the OpenRouter key counter

---

## A boot that reboots itself leaves no journal, because the initrd watchdog did it

**Where it bites:** any boot that hangs before `/var` is mounted — a module loaded from the initrd, an early oneshot, and the tensor unlock that `nixos/pc/gpu-unlock.nix` runs there

**Reproduction:** on 11 November 2026 the first boot after `nixos-rebuild boot` with `gpu_unlock.targets=all` went dark for about forty seconds and then rebooted the machine by itself. `journalctl --list-boots` holds no record of that attempt: the previous boot ends at 16:54:59 and the next starts at 16:55:44, and that second attempt unlocked the card in one second

**Misleading result:** the machine resets with no message, no journal entry and nothing on screen after a dark framebuffer, so it reads as a POST or memory-training fault and points at the firmware rather than at the kernel

**Mechanism:** `kernel.panic` is `0` on this host, so a Linux panic hangs the machine instead of rebooting it. The reset comes from the board's own watchdog: the initrd's systemd arms `/dev/watchdog` with `RuntimeWatchdogSec = 30s` and `RebootWatchdogSec = 10min` (`nixos/modules/system/boot/systemd/initrd.nix`), and a kernel spinning in a driver cannot let systemd pet it. Nothing reaches the journal because `/var` is not mounted yet

**Safe route:** read `sysctl kernel.panic` before blaming the firmware, since `0` rules a panic out and leaves the watchdog as the only reset in play, and do not search for a journal that cannot exist. Attribute the hang by taking the suspect parameter off for one boot — the bootloader edit, `gpu_unlock.targets` removed — and comparing. The next boot recovers on its own, and the generation before it always boots, so a repeat costs one reboot rather than a rescue
