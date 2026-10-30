import { randomUUID } from "node:crypto";
import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

type TokenKind = "input" | "output" | "cacheRead" | "cacheWrite";
type TokenMix = Record<TokenKind, number>;
interface Endpoint {
  tag: string;
  pricing?: { prompt?: string; completion?: string; input_cache_read?: string; input_cache_write?: string };
  context_length?: number;
  quantization?: string;
}
interface Route {
  only: string[];
  [key: string]: unknown;
}

export default function hoster(pi: ExtensionAPI) {
  const configured = process.env.PI_CODING_AGENT_DIR;
  const directory = configured?.startsWith("~/")
    ? join(homedir(), configured.slice(2)) : configured || join(homedir(), ".pi/agent");
  const stateFile = join(directory, "hoster.json");
  const privacy = { zdr: true, data_collection: "deny", require_parameters: true };

  function policy(model: string): Route {
    const models = JSON.parse(readFileSync(join(directory, "models.json"), "utf8"));
    const route = models.providers?.openrouter?.modelOverrides?.[model]?.compat?.openRouterRouting;
    if (!route || route.zdr !== true || route.data_collection !== "deny" ||
        route.require_parameters !== true || !Array.isArray(route.only) ||
        !route.only.length || !route.only.every((host: unknown) => typeof host === "string" && host.length)) {
      throw new Error("No valid Nix hoster policy for this model");
    }
    return route;
  }

  function choices(): Record<string, string> {
    try {
      const state = JSON.parse(readFileSync(stateFile, "utf8"));
      return state && typeof state === "object" && !Array.isArray(state) ? state : {};
    } catch {
      return {};
    }
  }

  function tokenMix(ctx: ExtensionContext): TokenMix {
    const totals: TokenMix = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };
    for (const entry of ctx.sessionManager?.getBranch() ?? []) {
      const message = entry.type === "message" ? entry.message : undefined;
      if (message?.role !== "assistant" || message.provider !== "openrouter" || message.model !== ctx.model?.id) continue;
      for (const key of Object.keys(totals) as TokenKind[]) {
        const count = message.usage?.[key];
        if (typeof count === "number" && Number.isFinite(count) && count > 0) totals[key] += count;
      }
    }
    return totals;
  }

  function rate(value: unknown): number | undefined {
    if ((typeof value !== "string" && typeof value !== "number") || String(value).trim() === "") return undefined;
    const number = Number(value);
    return Number.isFinite(number) && number >= 0 ? number * 1_000_000 : undefined;
  }

  function hostLabel(host: string, endpoint: Endpoint | undefined, mix: TokenMix): string {
    const pricing = endpoint?.pricing;
    const rates = { input: rate(pricing?.prompt), output: rate(pricing?.completion),
      cacheRead: rate(pricing?.input_cache_read), cacheWrite: rate(pricing?.input_cache_write) };
    const total = Object.values(mix).reduce((sum, count) => sum + count, 0);
    const keys = Object.keys(mix) as TokenKind[];
    const known = keys.every(key => !mix[key] || rates[key] !== undefined);
    const effective = total && known
      ? keys.reduce((sum, key) => sum + (mix[key] ? mix[key] * rates[key]! : 0), 0) / total
      : undefined;
    const dollars = (value: number | undefined) => value === undefined ? "—" : `$${Number(value.toPrecision(4))}/M`;
    const length = endpoint?.context_length;
    const context = typeof length === "number" && Number.isInteger(length) && length > 0
      ? length.toLocaleString("en-US") : "—";
    const quantization = endpoint?.quantization;
    return `${host} · in ${dollars(rates.input)} · out ${dollars(rates.output)} · ` +
      `eff ${effective === undefined ? "—" : `~${dollars(effective)}`} · ctx ${context}` +
      (typeof quantization === "string" && quantization && quantization !== "unknown" ? ` · ${quantization}` : "");
  }

  function groupEndpoints(host: string, endpoints: Endpoint[]): Endpoint | undefined {
    const matches = endpoints.filter(endpoint => endpoint.tag === host);
    if (!matches.length) return undefined;
    const pricing: NonNullable<Endpoint["pricing"]> = {};
    for (const key of ["prompt", "completion", "input_cache_read", "input_cache_write"] as const) {
      const values = matches.map(endpoint => rate(endpoint.pricing?.[key]));
      if (values.every(value => value !== undefined)) {
        pricing[key] = String(Math.max(...values as number[]) / 1_000_000);
      }
    }
    const lengths = matches.map(endpoint => endpoint.context_length);
    const context = lengths.every(length => typeof length === "number" && Number.isInteger(length) && length > 0)
      ? Math.min(...lengths as number[]) : undefined;
    const quantizations = new Set(matches.map(endpoint => endpoint.quantization?.trim().toLowerCase()));
    const quantization = quantizations.size === 1 ? [...quantizations][0] : undefined;
    return { tag: host, pricing, context_length: context, quantization };
  }

  async function hostLabels(model: string, hosts: string[], ctx: ExtensionContext): Promise<string[]> {
    let endpoints: Endpoint[] = [];
    try {
      const path = model.split("/").map(encodeURIComponent).join("/");
      const response = await fetch(`https://openrouter.ai/api/v1/models/${path}/endpoints`, {
        signal: AbortSignal.timeout(3000),
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const catalog = (await response.json()).data?.endpoints;
      if (!Array.isArray(catalog)) throw new Error("Invalid endpoint catalog");
      endpoints = catalog.filter(endpoint => endpoint && typeof endpoint.tag === "string");
    } catch {
      endpoints = [];
      ctx.ui.notify("Endpoint metadata unavailable; prices and context may be missing", "warning");
    }
    const mix = tokenMix(ctx);
    return hosts.map(host => hostLabel(host, groupEndpoints(host, endpoints), mix));
  }

  pi.registerCommand("hoster", {
    description: "Choose an allowed OpenRouter hoster (or auto) for the current model",
    handler: async (args, ctx) => {
      if (ctx.model?.provider !== "openrouter") {
        ctx.ui.notify("Hoster selection applies only to OpenRouter models", "info");
        return;
      }
      try {
        const model = ctx.model.id;
        const route = policy(model);
        const state = choices();
        const current = route.only.includes(state[model]) ? state[model] : "auto";
        let choice = args.trim();
        if (choice && choice !== "auto" && !route.only.includes(choice)) {
          ctx.ui.notify(`Hoster is not allowed: ${choice}`, "error");
          return;
        }
        const labels = await hostLabels(model, route.only, ctx);
        const options = ["auto", ...labels];
        if (!choice) {
          if (!ctx.hasUI) {
            ctx.ui.notify(`Hoster: ${current}. USD per 1M tokens; eff estimates this model's session mix, including cache\n${labels.join("\n")}`, "info");
            return;
          }
          const picked = await ctx.ui.select(`Hoster for ${model} (current: ${current})\nUSD/1M tokens; eff ≈ session mix incl. cache, not billed cost`, options);
          if (!picked) return;
          const index = options.indexOf(picked);
          choice = index === 0 ? "auto" : route.only[index - 1];
        }
        if (choice !== "auto" && !route.only.includes(choice)) {
          ctx.ui.notify(`Hoster is not allowed: ${choice}`, "error");
          return;
        }
        if (choice === "auto") delete state[model];
        else state[model] = choice;
        mkdirSync(directory, { recursive: true, mode: 0o700 });
        const temporary = `${stateFile}.${randomUUID()}`;
        writeFileSync(temporary, JSON.stringify(state, null, 2) + "\n", { mode: 0o600, flag: "wx" });
        renameSync(temporary, stateFile);
        const description = choice === "auto" ? "auto" : labels[route.only.indexOf(choice)];
        ctx.ui.notify(`Hoster for ${model}: ${description}`, "info");
      } catch (error) {
        ctx.ui.notify(String(error), "error");
      }
    },
  });

  pi.on("before_provider_request", (event, ctx) => {
    if (ctx.model?.provider !== "openrouter") return;
    const payload = event.payload as Record<string, unknown>;
    try {
      if (typeof payload?.model !== "string") throw new Error("Missing request model");
      const route = policy(payload.model);
      const choice = choices()[payload.model];
      const hosts = route.only.includes(choice) ? [choice] : route.only;
      const provider = payload.provider && typeof payload.provider === "object" ? payload.provider : {};
      return { ...payload, provider: {
        ...provider, ...route, ...privacy, only: hosts,
        order: hosts, allow_fallbacks: hosts.length > 1,
      } };
    } catch (error) {
      ctx.ui.notify(`Hoster policy unavailable: ${error}`, "error");
      return { ...payload, provider: {
        ...privacy, only: ["huix-no-authorized-hoster"], allow_fallbacks: false,
      } };
    }
  });
}
