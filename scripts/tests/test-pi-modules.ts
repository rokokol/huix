import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, watch, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { createServer } from "node:http";
import type { ExtensionAPI, ExtensionCommandContext, RegisteredCommand, RpcClient as RpcClientType,
  RpcExtensionUIRequest } from "@earendil-works/pi-coding-agent";

const root = mkdtempSync(join(tmpdir(), "pi-modules-"));
process.env.PI_CODING_AGENT_DIR = root;
const source = "/nix/store/fixture-creative-pi-package";
writeFileSync(join(root, "modules.json"), JSON.stringify({ creative: { source, description: "Creative tools" } }));
const settingsFile = join(root, "settings.json");
const original = { theme: "system", enabledModels: ["openai-codex/*"],
  packages: ["/nix/store/automode", { source, skills: ["+skills/audio"], extensions: ["./mcp.ts"] }],
  extensions: ["/nix/store/protected-host-policy.ts"] };
writeFileSync(settingsFile, JSON.stringify(original));
const { setupModules: extension } = await import(pathToFileURL(resolve(process.argv[2])).href) as {
  setupModules: (pi: ExtensionAPI) => void;
};
let command!: RegisteredCommand;
let reloads = 0;
let picked: string | undefined;
let menuOptions: string[] = [];
const notices: string[] = [];
const ctx = { hasUI: false, isIdle: () => true,
  reload: async () => { reloads++; },
  ui: { select: async (_title: string, options: string[]) => {
    menuOptions = options;
    assert(options.some(option => option.includes("creative")));
    assert(!options.some(option => option.includes("automode")));
    return picked ? options.find(option => option.includes(picked!)) : undefined;
  }, notify: (message: string) => notices.push(message) } } as unknown as ExtensionCommandContext;
extension({ getCommands: () => [], getMcpServers: () => [], registerCommand: (name: string, definition: RegisteredCommand) => {
  assert.equal(name, "modules"); command = definition;
} } as unknown as ExtensionAPI);
const settings = () => JSON.parse(readFileSync(settingsFile, "utf8"));
await command.handler("creative off", ctx);
assert.deepEqual(settings().packages, ["/nix/store/automode"]);
assert.deepEqual(settings().extensions, original.extensions);
assert.deepEqual(settings().enabledModels, original.enabledModels);
assert.equal(settings().theme, "system");
assert.equal(reloads, 1);
await command.handler("creative on", ctx);
assert.deepEqual(settings().packages, original.packages, "Per-package resource filters survive disable/enable");
assert.equal(reloads, 2);
await command.handler("automode off", ctx);
assert.equal(reloads, 2, "Safety extensions are outside the switchable module catalog");
await command.handler("", ctx);
assert(notices.at(-1)?.includes("[x] creative"), "Enabled modules use a checked box");
assert.equal(reloads, 2, "Cancelling the menu must not change anything");
await command.handler("creative off", ctx);
assert.equal(reloads, 3);
assert.deepEqual(settings().packages, ["/nix/store/automode"]);
picked = undefined;
await command.handler("", ctx);
assert(notices.at(-1)?.includes("[ ] creative"), "Disabled modules use an empty box");
assert.equal(reloads, 3);
writeFileSync(settingsFile, "broken json");
await command.handler("creative on", ctx);
assert.equal(readFileSync(settingsFile, "utf8"), "broken json", "Malformed settings must be left untouched");
assert.equal(reloads, 3);
console.log("PASS: whole modules toggle, preserve filters/preferences and cannot disable safety extensions");

const resources = await import(pathToFileURL(resolve(process.argv[2])).href);
const skill = { name: "fixture", description: "Synthetic skill", path: "/fixture/skills/fixture/SKILL.md",
  packageSource: source, packageRoot: "/fixture" };
const filtered = { packages: [{ source, skills: [], extensions: ["./mcp.ts"] }] };
resources.setSkillEnabled(filtered, skill, true);
assert.deepEqual(filtered.packages[0].skills, ["!**", "+skills/fixture/SKILL.md"], "Enabling one skill must not enable an explicitly disabled package's other skills");
resources.setSkillEnabled(filtered, skill, false);
assert.deepEqual(filtered.packages[0].skills, ["!**", "-skills/fixture/SKILL.md"]);
assert.deepEqual(filtered.packages[0].extensions, ["./mcp.ts"]);
const originalMcp = { url: "https://fixture.invalid/mcp", headers: { Authorization: "Bearer synthetic-not-a-secret" },
  exposure: "hidden", toolExposure: { recall: "direct" }, timeout: 180 };
assert.deepEqual(resources.configuredMcp(originalMcp, { tools: { retain: "hidden" } }),
  { ...originalMcp, toolExposure: { recall: "direct", retain: "hidden" } });
assert.deepEqual(originalMcp.toolExposure, { recall: "direct" }, "Resource preferences must not mutate source routing or credentials");
const nodes = [{ id: "module:fixture", name: "fixture", kind: "module", enabled: true, tokens: 0,
  children: [{ id: "skill:fixture", name: "skill", kind: "skill", enabled: true, tokens: 25, children: [] }] }];
assert.equal(resources.nodeTokens(nodes[0]), 25, "Folder sums must not double count children");
const results: boolean[] = [];
const component = resources.resourceTree(nodes, (accepted: boolean) => results.push(accepted), {
  matchesKey: (key: string, expected: string) => key === expected,
  truncateToWidth: (text: string, width: number) => text.slice(0, width),
});
assert(component.render(100).some((line: string) => line.includes("≈ 25")));
component.handleInput("right");
component.handleInput("down");
component.handleInput(" ");
assert.equal(resources.nodeTokens(nodes[0]), 0);
component.handleInput("escape");
assert.deepEqual(results, [false], "Escape cancels rather than applying changes");
writeFileSync(settingsFile, JSON.stringify(original));
const registryKey = Symbol.for("pi-subagents:manager");
const globalRegistry = globalThis as unknown as Record<symbol, unknown>;
globalRegistry[registryKey] = { hasRunning: () => true };
const beforeBlocked = readFileSync(settingsFile, "utf8");
try {
  await command.handler("creative off", ctx);
  assert.equal(readFileSync(settingsFile, "utf8"), beforeBlocked, "Live subagents must prevent reload before settings are written");
  assert.equal(reloads, 3);
  assert(notices.at(-1)?.includes("Subagents are running"));
} finally {
  delete globalRegistry[registryKey];
}
const mcpFile = join(root, "mcp.json");
const fileConfig = { mcpServers: { external: { url: "https://fixture.invalid/mcp", headers: { Authorization: "Bearer synthetic-not-a-secret" } } }, other: "preserved" };
writeFileSync(mcpFile, JSON.stringify(fileConfig));
await command.handler("mcp external off", ctx);
const updatedFileConfig = JSON.parse(readFileSync(mcpFile, "utf8"));
assert.equal(updatedFileConfig.mcpServers.external.enabled, false);
assert.deepEqual(updatedFileConfig.mcpServers.external.headers, fileConfig.mcpServers.external.headers);
assert.equal(updatedFileConfig.other, "preserved");
assert.equal(reloads, 4, "File-defined MCP changes use one guarded reload");
const memoryNodes = [{ id: "server:memory", name: "memory", kind: "server", server: "memory", enabled: true, tokens: 10,
  children: ["retain", "recall", "invalidate_memory", "reflect"].map(tool => ({
    id: `tool:memory/${tool}`, name: tool, kind: "tool", server: "memory", tool,
    enabled: tool !== "reflect", mode: tool === "reflect" ? "hidden" : "direct", tokens: 100, children: [],
  })) }];
const memoryUi = resources.resourceTree(memoryNodes, () => {}, {
  matchesKey: (key: string, expected: string) => key === expected,
  truncateToWidth: (text: string, width: number) => text.slice(0, width),
});
memoryUi.handleInput("ctrl+r");
assert.deepEqual(memoryNodes[0].children.filter(tool => tool.enabled).map(tool => tool.tool), ["recall"]);
memoryUi.handleInput("ctrl+w");
assert.deepEqual(memoryNodes[0].children.filter(tool => tool.enabled).map(tool => tool.tool), ["retain", "recall", "invalidate_memory"]);
memoryUi.handleInput("right");
memoryUi.handleInput("down");
memoryUi.handleInput("ctrl+e");
assert.equal(memoryNodes[0].children[0].mode, "deferred");
assert.equal(resources.nodeTokens(memoryNodes[0].children[0]), 0, "Deferred schemas do not count as directly declared initial tools");
assert.equal(resources.nodeSchemaTokens(memoryNodes[0]), 300, "Tool schema sizes survive a non-direct exposure");
assert(memoryUi.render(100).some((line: string) => line.includes("retain") && line.includes("schema")),
  "A deferred tool shows its schema size instead of a bare zero");
memoryNodes[0].enabled = false;
assert.equal(resources.nodeSchemaTokens(memoryNodes[0]), 0, "A disabled MCP contributes no schema inventory");
memoryNodes[0].enabled = true;
assert.equal(resources.nodeSchemaTokens(memoryNodes[0]), 300, "Re-enabling the MCP restores its schema inventory");
const mcpNodes = [{ id: "module:mcp", name: "mcp", kind: "module", enabled: true, tokens: 0, children: [
  { id: "server:audacity", name: "audacity", kind: "server", server: "audacity", enabled: true, tokens: 1, children: [
    { id: "tool:audacity/read", name: "read", kind: "tool", server: "audacity", tool: "read", enabled: true, mode: "direct", tokens: 10, children: [] },
    { id: "tool:audacity/write", name: "write", kind: "tool", server: "audacity", tool: "write", enabled: true, mode: "direct", tokens: 10, children: [] },
  ] },
] }];
const mcpUi = resources.resourceTree(mcpNodes, () => {}, {
  matchesKey: (key: string, expected: string) => key === expected,
  truncateToWidth: (text: string, width: number) => text.slice(0, width),
});
mcpUi.handleInput("right");
assert(mcpUi.render(100).some((line: string) => line.includes("read")), "Opening a module shows its MCP servers as folders");
mcpUi.handleInput("down");
mcpUi.handleInput("down");
mcpUi.handleInput(" ");
assert.equal(mcpNodes[0].children[0].enabled, true, "A tool switch never clears the MCP folder box");
assert.equal(mcpNodes[0].children[0].children[0].enabled, false);
mcpUi.handleInput("up");
mcpUi.handleInput(" ");
assert.equal(mcpNodes[0].children[0].enabled, false, "The MCP folder has its own switch");
assert.deepEqual(mcpNodes[0].children[0].children.map(tool => tool.enabled), [false, true], "MCP-off keeps the tool set");
mcpUi.handleInput(" ");
assert.equal(mcpNodes[0].children[0].enabled, true);
assert.deepEqual(mcpNodes[0].children[0].children.map(tool => tool.enabled), [false, true], "MCP-on restores the kept tool set");
const nestedModules = [{ id: "module:research", name: "research", kind: "module", enabled: true, tokens: 0, children: [
  { id: "module:deep-research", name: "deep-research", kind: "module", enabled: true, tokens: 0, children: [
    { id: "skill:deep-research/example", name: "example — skill", kind: "skill", enabled: true, tokens: 5, children: [] },
  ] },
] }];
const nestedUi = resources.resourceTree(nestedModules, () => {}, {
  matchesKey: (key: string, expected: string) => key === expected,
  truncateToWidth: (text: string, width: number) => text.slice(0, width),
});
nestedUi.handleInput("right");
assert(nestedUi.render(100).some((line: string) => line.includes("deep-research")), "Nested modules expand under their parent");
nestedUi.handleInput(" ");
assert.equal(nestedModules[0].enabled, false);
assert.equal(nestedModules[0].children[0].enabled, true, "Nested modules keep their own switch");
nestedUi.handleInput(" ");
assert.equal(nestedModules[0].enabled, true);
const searchNodes = [{ id: "module:search", name: "search", kind: "module", enabled: true, tokens: 0, children: [
  { id: "skill:search/alpha", name: "alpha — skill", kind: "skill", enabled: true, tokens: 5, children: [] },
  { id: "skill:search/beta", name: "beta — skill", kind: "skill", enabled: true, tokens: 5, children: [] },
] }];
const searchUi = resources.resourceTree(searchNodes, () => {}, {
  matchesKey: (key: string, expected: string) => key === expected,
  truncateToWidth: (text: string, width: number) => text.slice(0, width),
});
searchUi.handleInput("right");
searchUi.handleInput("b");
for (const character of "eta") searchUi.handleInput(character);
const searchLines = searchUi.render(100);
assert(searchLines.some((line: string) => line.includes("> beta▌")), "Typing the first character starts the search");
assert(searchLines.some((line: string) => line.includes("beta — skill")), "Search keeps matching rows");
assert(!searchLines.some((line: string) => line.includes("alpha — skill")), "Search hides non-matching rows");
assert(searchLines[0]?.startsWith("─") && searchLines[0].includes("Resources"), "The resource panel has a border without side rails");
searchUi.handleInput("escape");
assert(searchUi.render(100).some((line: string) => line.includes("alpha — skill")), "Escape clears the search filter");
const narrowLines = memoryUi.render(80);
assert(narrowLines.some((line: string) => line.includes("Esc cancel")), "Cancel help must remain visible in a normal-width overlay");
assert(narrowLines.every((line: string) => line.length <= 80), "Overlay text must fit its width");
assert(component.render(120).some((line: string) => line.includes("25 if on")), "Disabled skills must show their potential initial contribution");
const pendingUi = resources.resourceTree([{ id: "server:pending", name: "pending", kind: "server", server: "pending",
  enabled: true, tokens: 0, children: [] }], () => {}, {
  matchesKey: (key: string, expected: string) => key === expected,
  truncateToWidth: (text: string, width: number) => text.slice(0, width),
});
assert(pendingUi.render(100).some((line: string) => line.includes("+ ?")), "Undiscovered MCP schemas must not be presented as a known zero cost");

const batchRoot = mkdtempSync(join(tmpdir(), "pi-resource-batch-"));
const batchGroup = join(batchRoot, "creative");
mkdirSync(join(batchGroup, "skills/fixture"), { recursive: true });
writeFileSync(join(batchGroup, "skills/fixture/SKILL.md"), "---\nname: fixture\ndescription: Synthetic batch skill\n---\nFixture\n");
writeFileSync(join(batchRoot, "modules.json"), JSON.stringify({ creative: { source: batchGroup } }));
const batchSettings = join(batchRoot, "settings.json");
const batchPackage = { source: batchGroup, skills: ["+skills/fixture/SKILL.md"], extensions: ["./mcp.ts"] };
const helpers = { matchesKey: (key: string, expected: string) => key === expected,
  truncateToWidth: (text: string, width: number) => text.slice(0, width) };
let batchCommand!: RegisteredCommand;
let batchReloads = 0;
let confirms = 0;
const batchNotices: string[] = [];
const batchContext = { hasUI: true, isIdle: () => true, reload: async () => { batchReloads++; },
  ui: { notify: (text: string) => batchNotices.push(text), confirm: async () => { confirms++; return true; },
    custom: async (factory: Function, options: { overlayOptions?: { anchor?: string } }) => {
      assert.equal(options.overlayOptions?.anchor, "bottom-center", "The resource panel opens at the bottom");
      let accepted = false;
      const tree = factory({ requestRender() {}, terminal: { rows: 40 } }, {}, {}, (value: boolean) => { accepted = value; });
      for (const key of [" ", "right", "down", " ", "enter"]) tree.handleInput(key);
      return accepted;
    } } } as unknown as ExtensionCommandContext;
process.env.PI_CODING_AGENT_DIR = batchRoot;
resources.setupModules({ getCommands: () => [], getMcpServers: () => [], registerCommand: (_name: string, definition: RegisteredCommand) => {
  batchCommand = definition;
} }, helpers);
try {
  writeFileSync(batchSettings, JSON.stringify({ packages: [], huixDisabledModules: { creative: batchPackage } }));
  await batchCommand.handler("", batchContext);
  let value = JSON.parse(readFileSync(batchSettings, "utf8"));
  assert.equal(batchReloads, 1, JSON.stringify(batchNotices));
  assert.equal(value.packages[0].source, batchGroup);
  assert(value.packages[0].skills.includes("-skills/fixture/SKILL.md"), "Batch enable must restore module before applying its skill edits");
  assert.deepEqual(value.packages[0].extensions, batchPackage.extensions);

  await batchCommand.handler("", batchContext);
  value = JSON.parse(readFileSync(batchSettings, "utf8"));
  assert.equal(batchReloads, 2, JSON.stringify(batchNotices));
  assert.deepEqual(value.packages, []);
  assert(value.huixDisabledModules.creative.skills.includes("+skills/fixture/SKILL.md"), "Batch disable must remember skill edits before removing module");
  assert.equal(confirms, 2);
} finally {
  process.env.PI_CODING_AGENT_DIR = root;
}
console.log("PASS: selective skill filters, safe MCP overlays, folder token sums, cancel and live-subagent guard");

if (process.argv[3]) {
  const piRoot = process.argv[3];
  const { RpcClient } = await import(pathToFileURL(join(piRoot, "dist/modes/rpc/rpc-client.js")).href) as {
    RpcClient: typeof RpcClientType;
  };
  const group = join(root, "creative");
  mkdirSync(join(group, "skills/fixture"), { recursive: true });
  writeFileSync(join(group, "package.json"), JSON.stringify({ name: "@huix/creative",
    pi: { extensions: ["./mcp.ts"], skills: ["./skills"] } }));
  writeFileSync(join(group, "skills/fixture/SKILL.md"), "---\nname: fixture\ndescription: Synthetic module skill\n---\nRead the fixture\n");
  writeFileSync(join(group, "mcp.ts"), `export default function(pi) {
    pi.registerMcpServer("fixture-module", { url: "http://127.0.0.1:9/mcp" });
    pi.registerCommand("module-marker", { handler: async () => {} });
  }`);
  const inspector = join(root, "inspect.ts");
  writeFileSync(inspector, `export default function(pi) {
    pi.on("session_start", (_event, ctx) => ctx.ui.notify("MODULE_READY", "info"));
    pi.registerCommand("module-probe", { handler: async (_args, ctx) =>
      ctx.ui.notify("MCP:" + JSON.stringify(pi.getMcpServers().map(server => server.name)), "info") });
  }`);
  writeFileSync(join(root, "modules.json"), JSON.stringify({ creative: { source: group, description: "Creative fixture" } }));
  writeFileSync(settingsFile, JSON.stringify({ packages: [group],
    extensions: [resolve(process.argv[2]), inspector, "-builtin:mcp"],
    enableAnalytics: false, enableInstallTelemetry: false }));
  const client = new RpcClient({ cliPath: join(piRoot, "dist/bundle/cli.js"), cwd: root,
    env: { HOME: root, PI_CODING_AGENT_DIR: root, PI_TELEMETRY: "0", PI_OFFLINE: "1" },
    args: ["--offline", "--no-session", "--no-context-files"],
  });
  const seen: string[] = [];
  client.onEvent(raw => {
    const event = raw as unknown as RpcExtensionUIRequest;
    if (event.type === "extension_ui_request" && event.method === "notify") seen.push(event.message);
    if (event.type === "extension_ui_request" && event.method === "confirm") {
      const transport = client as unknown as { process: { stdin: { write(data: string): void } } };
      transport.process.stdin.write(JSON.stringify({ type: "extension_ui_response", id: event.id, confirmed: true }) + "\n");
    }
  });
  const ready = () => new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => { unsubscribe(); reject(new Error("Module reload did not finish")); }, 15000);
    const unsubscribe = client.onEvent(raw => {
      const event = raw as unknown as RpcExtensionUIRequest;
      if (event.type === "extension_ui_request" && event.method === "notify" && event.message === "MODULE_READY") {
        clearTimeout(timer); unsubscribe(); resolve();
      }
    });
  });
  try {
    const started = ready();
    await client.start();
    await started;
    let commands = await client.getCommands();
    assert(commands.some(command => command.name === "module-marker"));
    assert(commands.some(command => command.source === "skill" && command.name.includes("fixture")));
    await client.prompt("/module-probe");
    assert(seen.includes('MCP:["fixture-module"]'));
    const disabled = ready();
    await client.prompt("/modules creative off");
    await disabled;
    commands = await client.getCommands();
    assert(!commands.some(command => command.name === "module-marker"));
    assert(!commands.some(command => command.source === "skill" && command.name.includes("fixture")));
    await client.prompt("/module-probe");
    assert.equal(seen.at(-1), "MCP:[]");
    const enabled = ready();
    await client.prompt("/modules creative on");
    await enabled;
    commands = await client.getCommands();
    assert(commands.some(command => command.name === "module-marker"));
    assert(commands.some(command => command.source === "skill" && command.name.includes("fixture")));
    await client.prompt("/module-probe");
    assert.equal(seen.at(-1), 'MCP:["fixture-module"]');
    console.log("PASS: real Pi reload removes and restores module skills, extensions and MCP registrations together");
  } finally {
    await client.stop();
  }

  const mcpRoot = mkdtempSync(join(tmpdir(), "pi-resource-mcp-"));
  let toolCalls = 0;
  let modelTool: string | undefined;
  const mcp = createServer(async (request, response) => {
    if (request.method !== "POST") { response.writeHead(405); response.end(); return; }
    let body = "";
    for await (const chunk of request) body += chunk;
    const message = JSON.parse(body);
    if (Array.isArray(message.messages)) {
      const name = modelTool;
      modelTool = undefined;
      const delta = name ? { role: "assistant", tool_calls: [{ index: 0, id: `synthetic_${Date.now()}`, type: "function",
        function: { name, arguments: "{}" } }] } : { role: "assistant", content: "OK" };
      response.writeHead(200, { "Content-Type": "text/event-stream" });
      for (const [part, finish_reason] of [[delta, null], [{}, name ? "tool_calls" : "stop"]]) {
        response.write(`data: ${JSON.stringify({ id: "synthetic", object: "chat.completion.chunk", created: 1,
          model: "smoke", choices: [{ index: 0, delta: part, finish_reason }] })}\n\n`);
      }
      response.end("data: [DONE]\n\n");
      return;
    }
    if (!Object.hasOwn(message, "id")) { response.writeHead(202); response.end(); return; }
    let result: unknown = {};
    if (message.method === "initialize") result = { protocolVersion: "2025-03-26", capabilities: { tools: {} }, serverInfo: { name: "synthetic", version: "1" } };
    else if (message.method === "tools/list") result = { tools: ["a-b", "a_b"].map(name => ({ name,
      description: `Synthetic ${name}`, inputSchema: { type: "object", properties: {} } })) };
    else if (message.method === "tools/call") { toolCalls++; result = { content: [{ type: "text", text: "synthetic-ok" }] }; }
    response.writeHead(200, { "Content-Type": "application/json" });
    response.end(JSON.stringify({ jsonrpc: "2.0", id: message.id, result }));
  });
  await new Promise<void>(resolve => mcp.listen(0, "127.0.0.1", resolve));
  const port = (mcp.address() as { port: number }).port;
  const inspectMcp = join(mcpRoot, "inspect.ts");
  writeFileSync(inspectMcp, `export default function(pi) {
    let starts=0;
    pi.on("session_start", ()=>{starts++;});
    pi.registerMcpServer("fixture", {url:"http://127.0.0.1:${port}/mcp",exposure:"direct"});
    pi.registerCommand("resource-state", {handler: async(_,ctx)=>ctx.ui.notify("STATE:"+JSON.stringify({starts,tools:pi.getAllTools().filter(t=>t.namespace?.aliases?.includes("fixture")).map(t=>({name:t.name,exposure:t.exposure}))}),"info")});
  }`);
  writeFileSync(join(mcpRoot, "modules.json"), "{}");
  writeFileSync(join(mcpRoot, "models.json"), JSON.stringify({ providers: { fixture: {
    api: "openai-completions", apiKey: "synthetic-not-a-secret", baseUrl: `http://127.0.0.1:${port}/llm/v1`,
    models: [{ id: "smoke", reasoning: false, contextWindow: 32000, maxTokens: 256 }],
  } } }));
  writeFileSync(join(mcpRoot, "settings.json"), JSON.stringify({ packages: [],
    extensions: [resolve(process.argv[2]), inspectMcp, "-builtin:mcp"], enableAnalytics: false, enableInstallTelemetry: false }));
  const mcpClient = new RpcClient({ cliPath: join(piRoot, "dist/bundle/cli.js"), cwd: mcpRoot,
    provider: "fixture", model: "smoke",
    env: { HOME: mcpRoot, PI_CODING_AGENT_DIR: mcpRoot, PI_OFFLINE: "1", PI_TELEMETRY: "0" },
    args: ["--offline", "--no-session", "--no-context-files", "--no-skills"] });
  const messages: string[] = [];
  let confirmResources = true;
  let resourceConfirmations = 0;
  const cacheReady = (mode = "direct") => new Promise<void>((resolve, reject) => {
    const timeout = setTimeout(() => { watcher.close(); reject(new Error("Missing native MCP registration")); }, 15000);
    const watcher = watch(mcpRoot, (_event, filename) => {
      if (filename !== "resources-cache.json") return;
      const cache = JSON.parse(readFileSync(join(mcpRoot, "resources-cache.json"), "utf8"));
      if (cache.tools?.fixture?.["a-b"]?.exposure === mode && cache.tools?.fixture?.a_b) {
        clearTimeout(timeout); watcher.close(); resolve();
      }
    });
  });
  const nextNotice = (match: (text: string) => boolean) => new Promise<string>((resolve, reject) => {
    const timeout = setTimeout(() => { unsubscribe(); reject(new Error("Missing resource notice; observed: " + JSON.stringify(messages))); }, 15000);
    const unsubscribe = mcpClient.onEvent(raw => {
      const event = raw as unknown as RpcExtensionUIRequest;
      if (event.type === "extension_ui_request" && event.method === "notify" && match(event.message)) {
        clearTimeout(timeout); unsubscribe(); resolve(event.message);
      }
    });
  });
  mcpClient.onEvent(raw => {
    const event = raw as unknown as RpcExtensionUIRequest;
    if (event.type === "extension_ui_request" && event.method === "notify") messages.push(event.message);
    if (event.type === "extension_ui_request" && event.method === "confirm") {
      assert(event.message.includes("cached prefix"));
      resourceConfirmations++;
      const transport = mcpClient as unknown as { process: { stdin: { write(data: string): void } } };
      transport.process.stdin.write(JSON.stringify({ type: "extension_ui_response", id: event.id, confirmed: confirmResources }) + "\n");
    }
  });
  try {
    const initialReady = cacheReady();
    await mcpClient.start();
    await initialReady;
    const cached = JSON.parse(readFileSync(join(mcpRoot, "resources-cache.json"), "utf8"));
    const firstName = cached.tools.fixture["a-b"].modelName;
    const secondName = cached.tools.fixture.a_b.modelName;
    assert.notEqual(firstName, secondName, "Original MCP names must not be guessed from normalized tool names");
    confirmResources = false;
    await mcpClient.prompt("/modules tool fixture a-b hidden");
    assert.equal(resourceConfirmations, 1, "Live MCP changes must warn before applying");
    assert.equal(JSON.parse(readFileSync(join(mcpRoot, "resources-cache.json"), "utf8")).tools.fixture["a-b"].exposure, "direct");
    confirmResources = true;
    const disabled = nextNotice(text => text.startsWith("MCP preferences saved"));
    await mcpClient.prompt("/modules tool fixture a-b hidden");
    await disabled;
    const stateNotice = nextNotice(text => text.startsWith("STATE:"));
    await mcpClient.prompt("/resource-state");
    const state = JSON.parse((await stateNotice).slice(6));
    assert.equal(state.starts, 1, "MCP changes must not reload the whole session");
    assert.equal(state.tools.find((tool: { name: string }) => tool.name === firstName).exposure, "hidden");
    modelTool = firstName;
    const rejectedEvents = await mcpClient.promptAndWait("Synthetic hidden-tool invocation.", undefined, 15000);
    assert(rejectedEvents.some(event => event.type === "tool_execution_end" && event.toolName === firstName && event.isError), JSON.stringify(rejectedEvents));
    assert.equal(toolCalls, 0, "Hidden tools must not reach the MCP server");
    const enabled = cacheReady();
    await mcpClient.prompt("/modules tool fixture a-b direct");
    await enabled;
    modelTool = secondName;
    const called = await mcpClient.promptAndWait("Synthetic enabled-tool invocation.", undefined, 15000);
    assert(called.some(event => event.type === "tool_execution_end" && event.toolName === secondName && !event.isError && JSON.stringify(event.result).includes("synthetic-ok")));
    assert.equal(toolCalls, 1);
    assert.equal(JSON.parse(readFileSync(join(mcpRoot, "resources.json"), "utf8")).servers.fixture.tools["a-b"], "direct");
    console.log("PASS: real Pi native MCP per-tool controls preserve exact names, reject hidden calls and reconfigure without session reload");
  } finally {
    await mcpClient.stop();
    await new Promise<void>(resolve => mcp.close(() => resolve()));
  }
}
