import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { createServer } from "node:http";
import type { AddressInfo } from "node:net";
import type { ExtensionAPI, ExtensionCommandContext, RpcClient as RpcClientType,
  RpcExtensionUIRequest, RegisteredCommand, ExtensionContext } from "@earendil-works/pi-coding-agent";

interface Endpoint {
  tag: string;
  pricing?: Record<string, string>;
  context_length?: number;
  quantization?: string;
}
interface RequestPayload {
  provider: { only: string[]; allow_fallbacks?: boolean; zdr: boolean; data_collection: string; require_parameters: boolean };
}
type TestHook = (event: { payload: unknown }, context: typeof ctx) => RequestPayload | undefined;

const directory = mkdtempSync(join(tmpdir(), "pi-hoster-"));
process.env.PI_CODING_AGENT_DIR = directory;
const { default: extension } = await import(pathToFileURL(resolve(process.argv[2])).href) as { default: (pi: ExtensionAPI) => void };
const model = "fixture/model";
const policy = { zdr: true, data_collection: "deny", require_parameters: true,
  only: ["first/fp8", "second/fp4"], order: ["first/fp8", "second/fp4"] };
const modelsFile = join(directory, "models.json");
const stateFile = join(directory, "hoster.json");
const models: { providers: { openrouter: {
  api?: string; apiKey?: string; baseUrl?: string;
  models?: { id: string; reasoning: boolean; contextWindow: number; maxTokens: number }[];
  modelOverrides: Record<string, { compat: { openRouterRouting: typeof policy } }>;
} } } = { providers: { openrouter: { modelOverrides: {
  [model]: { compat: { openRouterRouting: policy } },
} } } };
writeFileSync(modelsFile, JSON.stringify(models));
let command!: (args: string, context: typeof ctx) => Promise<void>;
let hook!: TestHook;
let startup!: (event: unknown, context: ExtensionContext) => void;
let registered: { models: { id: string }[] };
let selected: string | undefined;
const messages: string[] = [];
let labels: string[] = [];
let catalog: Endpoint[] = [
  { tag: "first/fp8", pricing: { prompt: "0.00000008", completion: "0.0000005", input_cache_read: "0.000000012" },
    context_length: 1048576, quantization: "fp8" },
  { tag: "second/fp4", pricing: { prompt: "0", completion: "0.0000002" },
    context_length: 64000, quantization: "fp4" },
  { tag: "unapproved", pricing: { prompt: "0", completion: "0" } },
];
const originalFetch = globalThis.fetch;
let fetchFailed = false;
let metadataRequests = 0;
globalThis.fetch = async (url, options) => {
  metadataRequests++;
  assert.equal(url, "https://openrouter.ai/api/v1/models/fixture/model/endpoints");
  assert(!options?.headers, "Public metadata must not send credentials");
  if (fetchFailed) throw new Error("fixture offline");
  return Response.json({ data: { endpoints: catalog } });
};
let entries: { type: string; message: { role: string; provider: string; model: string;
  usage: { input: number; output: number; cacheRead: number; cacheWrite: number } } }[] = [];
const ctx = { model: { provider: "openrouter", id: model }, hasUI: true,
  sessionManager: { getBranch: () => entries },
  ui: { select: async (_title: string, choices: string[]) => {
    labels = choices;
    return choices.find(label => label === selected || label.startsWith(`${selected} ·`));
  },
    notify: (message: string) => messages.push(message) } };
function load() {
  extension({ registerCommand: (name: string, definition: RegisteredCommand) => {
    assert.equal(name, "hoster");
    command = async (args, context) => { await definition.handler(args, context as unknown as ExtensionCommandContext); };
  }, registerProvider: (name: string, provider: typeof registered) => {
    assert.equal(name, "openrouter");
    registered = provider;
  }, on: (event: string, handler: TestHook) => {
    if (event === "session_start") { startup = handler as unknown as typeof startup; return; }
    assert.equal(event, "before_provider_request"); hook = handler;
  } } as unknown as ExtensionAPI);
}
const payload = { model, messages: [], provider: { ...policy, zdr: false, only: ["unapproved"] } };
const request = () => {
  const result = hook({ payload: structuredClone(payload) }, ctx);
  assert(result);
  return result;
};
load();
const registryContext = { ...ctx, modelRegistry: { getAll: () => [
  { provider: "openrouter", id: model },
  { provider: "openrouter", id: "unconfigured/model" },
  { provider: "openai-codex", id: "other" },
] } } as unknown as ExtensionContext;
startup({}, registryContext);
assert.deepEqual(registered!.models.map(model => model.id), [model]);
writeFileSync(modelsFile, "{}");
startup({}, registryContext);
assert.deepEqual(registered!.models, [], "Missing policy must not expose the built-in OpenRouter catalog");
writeFileSync(modelsFile, JSON.stringify(models));
startup({}, registryContext);
selected = "second/fp4";
assert.equal(metadataRequests, 0, "Do not contact the catalog before the user invokes /hoster");
await command("", ctx);
assert(labels.some(label => label.includes("first/fp8") && label.includes("in $0.08/M") &&
  label.includes("out $0.5/M") && label.includes("ctx 1,048,576") && label.endsWith("fp8")));
assert(labels.some(label => label.startsWith("second/fp4") && label.includes("in $0/M")));
assert(labels.some(label => label.startsWith("first/fp8") && label.includes("eff —")));
assert(!labels.some(label => label.includes("unapproved")));
entries = [
  { type: "message", message: { role: "assistant", provider: "openrouter", model,
    usage: { input: 800, output: 100, cacheRead: 100, cacheWrite: 0 } } },
  { type: "message", message: { role: "assistant", provider: "openai-codex", model: "other",
    usage: { input: 1000000, output: 0, cacheRead: 0, cacheWrite: 0 } } },
];
await command("", ctx);
assert(labels.some(label => label.startsWith("first/fp8") && label.includes("eff ~$0.1152/M")));
assert(labels.some(label => label.startsWith("second/fp4") && label.includes("eff —")), "Missing cache tariff is not free");
await command("second/fp4", ctx);
assert(messages.some(message => message.startsWith("Hoster for") && message.includes("second/fp4") && message.includes("ctx 64,000")));
const savedCatalog = catalog;
catalog = [{ tag: "first/fp8", pricing: { prompt: "invalid", completion: "" }, quantization: "unknown" }];
await command("", ctx);
assert(labels.some(label => label.startsWith("first/fp8") && label.includes("in —") && label.includes("out —") && label.includes("ctx —")));
assert(!labels.some(label => label.includes("unknown")));
catalog = savedCatalog;
const noUi = { ...ctx, hasUI: false };
await command("", noUi);
assert(messages.some(message => message.includes("first/fp8") && message.includes("second/fp4") && message.includes("USD per 1M")));
const requestsBeforeSelection = JSON.parse(readFileSync(stateFile, "utf8"))[model];
selected = undefined;
await command("", ctx);
assert.equal(JSON.parse(readFileSync(stateFile, "utf8"))[model], requestsBeforeSelection);
selected = "second/fp4";
fetchFailed = true;
await command("", ctx);
assert(labels.some(label => label.startsWith("second/fp4")), "Offline metadata must not prevent selection");
assert(messages.some(message => message.includes("unavailable")));
fetchFailed = false;
catalog = [{ tag: "first/fp8", pricing: { prompt: "0.00000008", completion: "0.0000005" },
  context_length: 1048576, quantization: "fp8" },
  { tag: "first/fp8", pricing: { prompt: "0.0000001", completion: "0.0000006" },
    context_length: 128000, quantization: "fp8" }];
await command("", ctx);
assert(labels.some(label => label.startsWith("first/fp8") && label.includes("ctx 128,000") && label.includes("in $0.1/M")),
  "Display must not promise one endpoint's lower rate or larger context for a shared tag");
assert(labels.some(label => label.startsWith("first/fp8") && label.includes("eff —")),
  "Missing cache tariff for either endpoint makes the estimate unavailable");
catalog = savedCatalog;
assert.equal(request().provider.only[0], "second/fp4");
assert.deepEqual(request().provider.only, ["second/fp4"]);
assert.equal(request().provider.allow_fallbacks, false);
assert.equal(JSON.parse(readFileSync(stateFile, "utf8"))[model], "second/fp4");
load();
assert.deepEqual(request().provider.only, ["second/fp4"]);
const beforeRejected = metadataRequests;
await command("unapproved", ctx);
assert.equal(metadataRequests, beforeRejected, "Invalid choices must be rejected without contacting the catalog");
assert.deepEqual(request().provider.only, ["second/fp4"]);
await command("auto", ctx);
assert.deepEqual(request().provider.only, policy.only);
writeFileSync(stateFile, JSON.stringify({ [model]: "unapproved", zdr: false }));
assert.deepEqual(request().provider.only, policy.only);
writeFileSync(stateFile, JSON.stringify({ [model]: "second/fp4" }));
policy.only = ["first/fp8"];
policy.order = ["first/fp8"];
writeFileSync(modelsFile, JSON.stringify(models));
assert.deepEqual(request().provider.only, ["first/fp8"]);
assert.equal(request().provider.zdr, true);
assert.equal(request().provider.data_collection, "deny");
assert.equal(request().provider.require_parameters, true);
writeFileSync(stateFile, "broken json");
assert.deepEqual(request().provider.only, ["first/fp8"]);
assert.equal(hook({ payload }, { ...ctx, model: { provider: "openai-codex", id: model } }), undefined);
writeFileSync(modelsFile, "broken json");
const blocked = request().provider;
assert.equal(blocked.zdr, true);
assert.equal(blocked.data_collection, "deny");
assert.equal(blocked.allow_fallbacks, false);
assert(!blocked.only.some(host => ["first/fp8", "second/fp4", "unapproved"].includes(host)));
console.log("PASS: hoster UI, persistence, invalid/stale choices, per-request policy and mandatory privacy");
console.log("PASS: endpoint prices, cache-aware effective estimate, context, quantization and offline fallback");
globalThis.fetch = originalFetch;

if (process.argv[3]) {
  const piRoot = process.argv[3];
  const { RpcClient } = await import(pathToFileURL(join(piRoot, "dist/modes/rpc/rpc-client.js")).href) as { RpcClient: typeof RpcClientType };
  const requests: RequestPayload[] = [];
  const server = createServer(async (request, response) => {
    let body = "";
    for await (const chunk of request) body += chunk;
    const data = JSON.parse(body);
    requests.push(data);
    response.writeHead(200, { "Content-Type": "text/event-stream" });
    for (const [delta, finish_reason] of [[{ role: "assistant", content: "OK" }, null], [{}, "stop"]]) {
      response.write(`data: ${JSON.stringify({ id: "fixture", object: "chat.completion.chunk",
        created: 1, model, choices: [{ index: 0, delta, finish_reason }] })}\n\n`);
    }
    response.end("data: [DONE]\n\n");
  });
  await new Promise<void>(resolve => server.listen(0, "127.0.0.1", resolve));
  policy.only = ["first/fp8", "second/fp4"];
  models.providers.openrouter = { ...models.providers.openrouter,
    api: "openai-completions", apiKey: "synthetic-key",
    baseUrl: `http://127.0.0.1:${(server.address() as AddressInfo).port}/v1`,
    models: [{ id: model, reasoning: false, contextWindow: 32000, maxTokens: 1000 }],
  };
  writeFileSync(modelsFile, JSON.stringify(models));
  writeFileSync(stateFile, "{}");
  const wrapper = join(directory, "hoster-fixture.ts");
  writeFileSync(wrapper, `import hoster from ${JSON.stringify(pathToFileURL(resolve(process.argv[2])).href)};
    export default function(pi) {
      const original = globalThis.fetch;
      globalThis.fetch = async (input, options) => {
        const url = new URL(typeof input === "string" ? input : input.url ?? String(input));
        if (url.origin === "https://openrouter.ai" && url.pathname.endsWith("/endpoints")) {
          return Response.json({ data: { endpoints: ${JSON.stringify(savedCatalog)} } });
        }
        if (url.origin === ${JSON.stringify(new URL(models.providers.openrouter.baseUrl!).origin)}) return original(input, options);
        throw new Error("Unexpected external request: " + url);
      };
      hoster(pi);
    }`);
  writeFileSync(join(directory, "settings.json"), JSON.stringify({
    extensions: [wrapper], enableInstallTelemetry: false, enableAnalytics: false,
  }));
  const client = new RpcClient({ cliPath: join(piRoot, "dist/bundle/cli.js"),
    cwd: directory, env: { HOME: directory, PI_CODING_AGENT_DIR: directory, PI_OFFLINE: "1", PI_TELEMETRY: "0" },
    provider: "openrouter", model,
    args: ["--offline", "--no-session", "--no-context-files", "--no-skills", "--thinking", "off"],
  });
  const notices: string[] = [];
  client.onEvent(raw => {
    const event = raw as unknown as RpcExtensionUIRequest;
    if (event.type !== "extension_ui_request") return;
    if (event.method === "notify") notices.push(event.message);
    if (event.method === "select") {
      notices.push(event.options.join("\n"));
      const transport = client as unknown as { process: { stdin: { write(data: string): void } } };
      transport.process.stdin.write(JSON.stringify({ type: "extension_ui_response", id: event.id,
        value: event.options.find(label => label.startsWith("first/fp8")) }) + "\n");
    }
  });
  try {
    await client.start();
    const available = await client.getAvailableModels();
    assert.deepEqual(available.filter(candidate => candidate.provider === "openrouter").map(candidate => candidate.id), [model],
      "OpenRouter's model picker must expose only models with a hoster policy");
    assert((await client.getCommands()).some(command => command.name === "hoster"));
    assert.equal(await client.prompt("/hoster"), "handled");
    assert.equal(await client.prompt("/hoster second/fp4"), "handled");
    await client.promptAndWait("Reply OK", undefined, 15000);
    assert.equal(requests.length, 1);
    assert.deepEqual(requests[0].provider.only, ["second/fp4"]);
    assert.equal(requests[0].provider.allow_fallbacks, false);
    assert.equal(requests[0].provider.zdr, true);
    assert.equal(requests[0].provider.data_collection, "deny");
    assert.equal(await client.prompt("/hoster auto"), "handled");
    await client.promptAndWait("Reply OK again", undefined, 15000);
    assert.deepEqual(requests[1].provider.only, policy.only);
    assert(notices.some(message => message.includes("in $0.08/M") && message.includes("ctx 1,048,576")));
    console.log("PASS: real Pi RPC /hoster changes outgoing provider routing without weakening privacy");
  } finally {
    await client.stop();
    await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
  }
}
