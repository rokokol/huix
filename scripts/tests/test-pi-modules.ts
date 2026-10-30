import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
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
const { default: extension } = await import(pathToFileURL(resolve(process.argv[2])).href) as {
  default: (pi: ExtensionAPI) => void;
};
let command!: RegisteredCommand;
let reloads = 0;
let picked: string | undefined;
let menuOptions: string[] = [];
const notices: string[] = [];
const ctx = { hasUI: true, isIdle: () => true,
  reload: async () => { reloads++; },
  ui: { select: async (_title: string, options: string[]) => {
    menuOptions = options;
    assert(options.some(option => option.includes("creative")));
    assert(!options.some(option => option.includes("automode")));
    return picked ? options.find(option => option.includes(picked!)) : undefined;
  }, notify: (message: string) => notices.push(message) } } as unknown as ExtensionCommandContext;
extension({ registerCommand: (name: string, definition: RegisteredCommand) => {
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
assert(menuOptions.some(option => option.startsWith("[x] creative")), "Enabled modules use a checked box");
assert.equal(reloads, 2, "Cancelling the menu must not change anything");
picked = "creative";
await command.handler("", ctx);
assert.equal(reloads, 3);
assert.deepEqual(settings().packages, ["/nix/store/automode"]);
picked = undefined;
await command.handler("", ctx);
assert(menuOptions.some(option => option.startsWith("[ ] creative")), "Disabled modules use an empty box");
assert.equal(reloads, 3);
writeFileSync(settingsFile, "broken json");
await command.handler("creative on", ctx);
assert.equal(readFileSync(settingsFile, "utf8"), "broken json", "Malformed settings must be left untouched");
assert.equal(reloads, 3);
console.log("PASS: whole modules toggle, preserve filters/preferences and cannot disable safety extensions");

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
}
