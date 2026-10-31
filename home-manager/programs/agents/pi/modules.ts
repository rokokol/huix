import { randomUUID } from "node:crypto";
import { existsSync, lstatSync, readFileSync, readdirSync, realpathSync, renameSync, statSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, relative } from "node:path";
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext, ExtensionFactory, McpExposure, McpServerConfig, Skill, ToolDefinition } from "@earendil-works/pi-coding-agent";

type Package = string | { source: string; [key: string]: unknown };
const sourceOf = (item: Package) => typeof item === "string" ? item : item.source;

type Settings = { packages: Package[]; skills?: string[]; huixDisabledModules?: Record<string, Package>; [key: string]: unknown };
type Catalog = Record<string, { source: string; description: string; servers?: string[]; parent?: string }>;
type Preferences = { servers: Record<string, { enabled?: boolean; tools?: Record<string, McpExposure> }>; disabledSkills: string[] };
type SkillEntry = { name: string; path: string; description: string; promptEnabled?: boolean; module?: string; packageSource?: string; packageRoot?: string };
type ToolEntry = { name: string; modelName: string; tokens: number; exposure?: string };
type Cache = { skills: Record<string, SkillEntry>; tools: Record<string, Record<string, ToolEntry>> };
export type ResourceNode = { id: string; name: string; kind: "module" | "skill" | "server" | "tool" | "separator";
  enabled: boolean; tokens: number; children: ResourceNode[]; skill?: SkillEntry; server?: string; tool?: string; mode?: McpExposure; file?: string };

export const estimatedTokens = (text: string) => Math.ceil([...text].length / 4);
const canonical = (path: string) => { try { return realpathSync(path); } catch { return path; } };
const readJson = <T>(path: string, fallback?: T): T => {
  if (!existsSync(path) && fallback !== undefined) return structuredClone(fallback);
  return JSON.parse(readFileSync(path, "utf8")) as T;
};
const saveJson = (path: string, value: unknown) => {
  const temporary = `${path}.${randomUUID()}`;
  writeFileSync(temporary, JSON.stringify(value, null, 2) + "\n", { mode: 0o600, flag: "wx" });
  renameSync(temporary, path);
};

export function resourcePreferences(path: string): Preferences {
  const value = readJson<Preferences>(path, { servers: {}, disabledSkills: [] });
  if (!value || !value.servers || typeof value.servers !== "object" || Array.isArray(value.servers) ||
      !Array.isArray(value.disabledSkills) || !value.disabledSkills.every(item => typeof item === "string")) {
    throw new Error("Invalid resource preferences; nothing was changed");
  }
  for (const entry of Object.values(value.servers)) {
    if (!entry || typeof entry !== "object" || (entry.enabled !== undefined && typeof entry.enabled !== "boolean") ||
        (entry.tools !== undefined && (!entry.tools || typeof entry.tools !== "object" || Array.isArray(entry.tools) ||
          !Object.values(entry.tools).every(mode => ["hidden", "direct", "deferred", "codemode"].includes(mode))))) {
      throw new Error("Invalid MCP preferences; nothing was changed");
    }
  }
  return value;
}

export function configuredMcp(config: McpServerConfig, preference?: Preferences["servers"][string]): McpServerConfig {
  return { ...config, ...(preference?.enabled !== undefined ? { enabled: preference.enabled } : {}),
    toolExposure: { ...config.toolExposure, ...preference?.tools } };
}

export function setSkillEnabled(settings: Settings, skill: SkillEntry, enabled: boolean) {
  const index = skill.packageSource ? settings.packages.findIndex(item => sourceOf(item) === skill.packageSource) : -1;
  if (index >= 0 && skill.packageRoot) {
    const item = settings.packages[index];
    const entry: { source: string; [key: string]: unknown } = typeof item === "string" ? { source: item } : { ...item };
    const selector = relative(skill.packageRoot, skill.path);
    const previous = entry.skills as string[] | undefined;
    if (previous !== undefined && (!Array.isArray(previous) || !previous.every(value => typeof value === "string"))) {
      throw new Error("Invalid package skill filters; nothing was changed");
    }
    entry.skills = [...(previous?.length === 0 ? ["!**"] : previous ?? []).filter(value => value !== `+${selector}` && value !== `-${selector}`),
      `${enabled ? "+" : "-"}${selector}`];
    settings.packages[index] = entry;
  } else if (!skill.packageSource) {
    if (settings.skills !== undefined && (!Array.isArray(settings.skills) || !settings.skills.every(value => typeof value === "string"))) {
      throw new Error("Invalid skill paths; nothing was changed");
    }
    settings.skills = [...(settings.skills ?? []).filter(value => value !== `+${skill.path}` && value !== `-${skill.path}`),
      `${enabled ? "+" : "-"}${skill.path}`];
  } else {
    throw new Error("Enable the skill's module before changing its skill filters");
  }
}

export function runningSubagents(): boolean {
  const registry = (globalThis as Record<symbol, unknown>)[Symbol.for("pi-subagents:manager")] as { hasRunning?: () => boolean } | undefined;
  if (registry && typeof registry.hasRunning !== "function") throw new Error("Cannot check active subagents; reload refused");
  return registry?.hasRunning?.() ?? false;
}

function scanSkills(path: string, visit: (path: string) => void, seen = new Set<string>(), depth = 0) {
  if (!existsSync(path) || depth > 5 || seen.size > 1000) return;
  const real = canonical(path);
  if (seen.has(real)) return;
  seen.add(real);
  if (statSync(path).isFile()) { if (path.endsWith("SKILL.md")) visit(path); return; }
  if (existsSync(join(path, "SKILL.md"))) { visit(join(path, "SKILL.md")); return; }
  for (const name of readdirSync(path)) scanSkills(join(path, name), visit, seen, depth + 1);
}

function skillFromFile(path: string): SkillEntry {
  const text = readFileSync(path, "utf8");
  const name = /^name:\s*["']?([^\n"']+)/m.exec(text)?.[1]?.trim() ?? path.split("/").at(-2) ?? path;
  const description = /^description:\s*["']?([^\n"']+)/m.exec(text)?.[1]?.trim() ?? "";
  return { name, path, description };
}

function matchesPattern(pattern: string, value: string) {
  return new RegExp(`^${pattern.split("*").map(part => part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join(".*")}$`).test(value);
}
function exposure(config: McpServerConfig, tool: string): McpExposure {
  const overrides = config.toolExposure ?? {};
  const exact = Object.hasOwn(overrides, tool) ? overrides[tool] : undefined;
  return exact ?? Object.entries(overrides).find(([pattern]) => matchesPattern(pattern, tool))?.[1] ?? config.exposure ?? "codemode";
}

export function nodeTokens(node: ResourceNode, parentEnabled = true): number {
  if (!parentEnabled || !node.enabled) return 0;
  if (node.kind === "tool") return node.mode === "direct" ? node.tokens : 0;
  const own = node.kind === "server" && !node.children.some(child => child.enabled && child.mode !== "direct") ? 0 : node.tokens;
  return own + node.children.reduce((total, child) => total + nodeTokens(child), 0);
}

export function nodeSchemaTokens(node: ResourceNode): number {
  if (!node.enabled) return 0;
  if (node.kind === "tool") return node.tokens;
  return node.children.reduce((total, child) => total + nodeSchemaTokens(child), 0);
}

function pendingSchemas(node: ResourceNode): boolean {
  return node.enabled && (node.kind === "server" && !node.children.length || node.children.some(pendingSchemas));
}

type Theme = { fg?: (color: string, text: string) => string; bold?: (text: string) => string };
type UiHelpers = { matchesKey: (data: string, key: string) => boolean;
  truncateToWidth: (text: string, width: number) => string;
  height?: () => number;
  theme?: Theme;
  readSkills?: (dir: string) => SkillEntry[];
  skillPrompt?: (skill: SkillEntry) => string };
export function resourceTree(nodes: ResourceNode[], done: (apply: boolean) => void, helpers: UiHelpers) {
  const expanded = new Set<string>();
  let selected = 0;
  let query = "";
  let searching = false;
  const hasMatch = (node: ResourceNode): boolean => {
    const needle = query.toLowerCase();
    return !needle || node.name.toLowerCase().includes(needle) || node.children.some(hasMatch);
  };
  const rows = () => {
    const result: { node: ResourceNode; depth: number; effective: boolean }[] = [];
    const walk = (items: ResourceNode[], depth: number, active: boolean) => {
      for (const node of items) {
        if (!hasMatch(node)) continue;
        result.push({ node, depth, effective: active });
        if (expanded.has(node.id) || (query && node.children.some(hasMatch))) {
          walk(node.children, depth + 1, active && node.enabled);
        }
      }
    };
    walk(nodes, 0, true);
    return result;
  };
  const pad = (line: string, width: number) => {
    const clipped = helpers.truncateToWidth(line, width);
    return clipped + " ".repeat(Math.max(0, width - clipped.length));
  };
  const paint = (color: string, text: string) => helpers.theme?.fg?.(color, text) ?? text;
  const bold = (text: string) => helpers.theme?.bold?.(text) ?? text;
  return {
    invalidate() {},
    render(width: number) {
      const all = rows();
      selected = Math.min(selected, Math.max(0, all.length - 1));
      const terminalRows = helpers.height?.() ?? 24;
      const visible = Math.max(1, Math.min(10, terminalRows - 8));
      const start = Math.max(0, selected - Math.floor(visible / 2));
      const search = searching ? `> ${query}▌` : query ? `> ${query}   (type to edit)` : "> type to search";
      const body: { text: string; color: string }[] = [
        { text: `initial contribution ≈ ${nodes.reduce((total, node) => total + nodeTokens(node), 0)}${nodes.some(pendingSchemas) ? " + ?" : ""} tok`, color: "muted" },
        { text: search, color: "accent" },
        { text: "type to search · ↑↓ move · ←→ folders", color: "dim" },
        { text: "Space toggle · Ctrl+E exposure · Ctrl+R/W memory", color: "dim" },
        { text: "Enter apply · Esc cancel", color: "dim" },
        ...all.slice(start, start + visible).map(({ node, depth, effective }, offset) => {
          if (node.kind === "separator") return { text: "──────────────── Ungrouped ────────────────", color: "dim" };
          const selectedRow = selected === start + offset;
          const arrow = node.children.length ? expanded.has(node.id) || (query && node.children.some(hasMatch)) ? "▾" : "▸" : " ";
          const label = `${selectedRow ? ">" : " "} ${"  ".repeat(depth)}${arrow} [${node.enabled ? "x" : " "}] ${node.name}${node.mode ? ` — ${node.enabled ? node.mode : "hidden"}` : ""}`;
          const count = nodeTokens(node, effective);
          const potential = nodeTokens({ ...node, enabled: true });
          const unknown = pendingSchemas({ ...node, enabled: true }) ? " + ?" : "";
          // A tool's schema exists even when its exposure keeps it out of the initial prompt.
          // Show that size, and keep the folder total limited to what the session pays up front.
          const cost = node.kind === "tool"
            ? !node.enabled || !effective
              ? `0 init · ≈ ${node.tokens} schema`
              : node.mode === "direct"
                ? `≈ ${count}${unknown} tok`
                : `0 init · ≈ ${node.tokens} schema · ${node.mode}`
            : !effective || !node.enabled
              ? `off · ≈ ${potential}${unknown} if on`
              : `≈ ${count}${unknown} tok`;
          return { text: helpers.truncateToWidth(label, Math.max(8, width - cost.length - 2)) + "  " + cost,
            color: selectedRow ? "accent" : node.enabled ? "text" : "dim" };
        }),
      ];
      const top = paint("border", `─${bold(" Resources ")}${"─".repeat(Math.max(0, width - 12))}`);
      const bottom = paint("border", "─".repeat(Math.max(0, width)));
      return [
        top,
        ...body.map(({ text, color }) => paint(color, pad(text, width))),
        bottom,
      ];
    },
    handleInput(data: string) {
      if (searching) {
        if (helpers.matchesKey(data, "escape")) { searching = false; query = ""; selected = 0; return; }
        if (helpers.matchesKey(data, "enter")) { searching = false; return; }
        if (helpers.matchesKey(data, "up")) { selected = Math.max(0, selected - 1); return; }
        if (helpers.matchesKey(data, "down")) { const all = rows(); selected = Math.min(all.length - 1, selected + 1); return; }
        if (data === "\x7f" || data === "\b") { query = query.slice(0, -1); selected = 0; return; }
        if (data.length === 1 && data >= " " && data !== "/") { query += data; selected = 0; return; }
        return;
      }
      const all = rows();
      const node = all[selected]?.node;
      if (helpers.matchesKey(data, "escape")) {
        if (query) { query = ""; selected = 0; } else done(false);
        return;
      }
      if (helpers.matchesKey(data, "enter")) { done(true); return; }
      if (helpers.matchesKey(data, "up")) selected = Math.max(0, selected - 1);
      else if (helpers.matchesKey(data, "down")) selected = Math.min(all.length - 1, selected + 1);
      else if (node && helpers.matchesKey(data, "right")) {
        // Opening a module shows its nested modules and MCP folders straight away. Every
        // folder keeps its own switch, so this is a view operation only.
        const expand = (item: ResourceNode) => {
          expanded.add(item.id);
          for (const child of item.children) if (child.kind === "server" || child.kind === "module") expand(child);
        };
        expand(node);
      }
      else if (node && helpers.matchesKey(data, "left")) expanded.delete(node.id);
      else if (node && data === " " && node.kind !== "separator") {
        // A server's box is its own switch: it never changes its tools. A tool's box is the
        // tool's own exposure and never changes the server box.
        node.enabled = !node.enabled;
        if (node.kind === "tool" && node.enabled && node.mode === "hidden") node.mode = "deferred";
      }
      else if (node?.kind === "tool" && helpers.matchesKey(data, "ctrl+e")) {
        const modes: McpExposure[] = ["direct", "deferred", "codemode", "hidden"];
        node.mode = modes[(modes.indexOf(node.mode ?? "hidden") + 1) % modes.length];
        node.enabled = node.mode !== "hidden";
      }
      else if (node?.kind === "server" && (node.server === "memory" || node.server === "memory-trial") &&
        (helpers.matchesKey(data, "ctrl+r") || helpers.matchesKey(data, "ctrl+w"))) {
        const read = helpers.matchesKey(data, "ctrl+r");
        node.enabled = true;
        for (const child of node.children) {
          child.enabled = read ? child.tool === "recall" : ["recall", "retain", "invalidate_memory"].includes(child.tool ?? "");
          if (child.enabled) child.mode = "direct";
        }
      }
      else {
        // Any ordinary character starts the search immediately, including the first one.
        // `/` only opens an empty search; every other printable character becomes its query.
        const printable = data.length > 0 && !data.startsWith("\x1b") && !/[\x00-\x1f\x7f]/.test(data);
        if (printable && data !== " ") {
          searching = true;
          if (data !== "/") query += data;
          selected = 0;
        }
      }
    },
  };
}

export function setupModules(pi: ExtensionAPI, helpers?: UiHelpers, nativeMcp?: ExtensionFactory) {
  const configured = process.env.PI_CODING_AGENT_DIR;
  const directory = configured?.startsWith("~/")
    ? join(homedir(), configured.slice(2)) : configured || join(homedir(), ".pi/agent");
  const settingsPath = join(directory, "settings.json");
  const preferencesPath = join(directory, "resources.json");
  const cachePath = join(directory, "resources-cache.json");
  let preferences = resourcePreferences(preferencesPath);
  const cache = readJson<Cache>(cachePath, { skills: {}, tools: {} });
  const catalog = () => readJson<Catalog>(join(directory, "modules.json"));
  const rememberTools = (definition: Pick<ToolDefinition, "name" | "label" | "namespace" | "description" | "parameters" | "exposure">) => {
    const server = definition.namespace?.aliases?.[0];
    if (!server || !definition.label.startsWith(`${server}/`)) return;
    const name = definition.label.slice(server.length + 1);
    const previous = Object.hasOwn(cache.tools, server) ? cache.tools[server] : {};
    cache.tools = { ...cache.tools, [server]: { ...previous, [name]: { name, modelName: definition.name, exposure: definition.exposure ?? "direct",
      tokens: estimatedTokens(JSON.stringify({ name: definition.name, description: definition.description, parameters: definition.parameters })) } } };
    saveJson(cachePath, cache);
  };
  let nativeReady: void | Promise<void> = undefined;
  let reconfigureMcp: ((ctx: ExtensionContext) => Promise<void>) | undefined;
  if (nativeMcp) {
    const facade = Object.create(pi) as ExtensionAPI;
    facade.getMcpServers = () => pi.getMcpServers().map(server => ({ ...server,
      config: configuredMcp(server.config, preferences.servers[server.name]) }));
    facade.registerTool = definition => { pi.registerTool(definition); rememberTools(definition); };
    facade.on = ((event: string, handler: unknown) => {
      if (event === "mcp_servers_change") {
        const onChange = handler as (event: { type: string; servers: ReturnType<ExtensionAPI["getMcpServers"]> }, ctx: ExtensionContext) => unknown;
        reconfigureMcp = async ctx => { await onChange({ type: "mcp_servers_change", servers: facade.getMcpServers() }, ctx); };
      }
      Reflect.apply(pi.on, pi, [event, handler]);
    }) as ExtensionAPI["on"];
    nativeReady = nativeMcp(facade);
  }

  const readSettings = (): Settings => {
    const settings = readJson<Settings>(settingsPath);
    if (!settings || typeof settings !== "object" || Array.isArray(settings) ||
        !Array.isArray(settings.packages) || !settings.packages.every(item =>
          typeof item === "string" || (item && typeof item === "object" && typeof item.source === "string"))) {
      throw new Error("Invalid Pi package settings; nothing was changed");
    }
    return settings;
  };

  const fileServers = (ctx: ExtensionCommandContext) => {
    const servers = new Map<string, { file: string; config: McpServerConfig }>();
    const paths = [join(directory, "mcp.json")];
    if (ctx.cwd && ctx.isProjectTrusted()) paths.push(join(ctx.cwd, ".pi/mcp.json"));
    for (const file of paths.filter(existsSync)) {
      const value = readJson<{ mcpServers?: Record<string, McpServerConfig> }>(file);
      for (const [name, config] of Object.entries(value.mcpServers ?? {})) {
        const base = servers.get(name)?.config;
        const merged = { ...base, ...config };
        if (("url" in merged && typeof merged.url === "string") || ("command" in merged && typeof merged.command === "string")) {
          servers.set(name, { file, config: merged as McpServerConfig });
        }
      }
    }
    return servers;
  };

  const tree = (settings: Settings, ctx: ExtensionCommandContext): ResourceNode[] => {
    const groups = catalog();
    const groupNodes = new Map<string, ResourceNode>(Object.entries(groups).map(([name, group]) => [name, {
      id: `module:${name}`, name, kind: "module", enabled: settings.packages.some(item => sourceOf(item) === group.source), tokens: 0, children: [],
    }]));
    // A declared parent turns a module into a folder of its parent. The child keeps its own
    // package switch, so nesting changes the view, not the set of enabled packages.
    const roots: ResourceNode[] = [];
    for (const [name, group] of Object.entries(groups)) {
      const node = groupNodes.get(name)!;
      const parent = group.parent ? groupNodes.get(group.parent) : undefined;
      if (parent && parent !== node) parent.children.push(node);
      else roots.push(node);
    }
    const ungrouped: ResourceNode[] = [];
    const addSkill = (skill: SkillEntry) => {
      const id = `${skill.module ?? "ungrouped"}/${skill.name}`;
      cache.skills[id] = skill;
    };
    for (const [name, group] of Object.entries(groups)) {
      const directory = join(group.source, "skills");
      if (helpers?.readSkills) {
        for (const skill of helpers.readSkills(directory)) addSkill({ ...skill, module: name, packageSource: group.source, packageRoot: group.source });
      } else {
        scanSkills(directory, path => addSkill({ ...skillFromFile(path), module: name, packageSource: group.source, packageRoot: group.source }));
      }
    }
    for (const command of pi.getCommands().filter(command => command.source === "skill")) {
      const path = command.sourceInfo.path;
      if (Object.values(cache.skills).some(skill => canonical(skill.path) === canonical(path))) continue;
      addSkill({ name: command.name.replace(/^skill:/, ""), description: command.description ?? "", path,
        ...(command.sourceInfo.origin === "package" ? { packageSource: command.sourceInfo.source, packageRoot: command.sourceInfo.baseDir } : {}) });
    }
    const activeSkills = new Set(pi.getCommands().filter(command => command.source === "skill").map(command => canonical(command.sourceInfo.path)));
    for (const [key, skill] of Object.entries(cache.skills)) {
      const groupEnabled = skill.module ? groupNodes.get(skill.module)?.enabled : true;
      const node: ResourceNode = { id: `skill:${key}`, name: `${skill.name} — skill`, kind: "skill", skill,
        enabled: groupEnabled ? activeSkills.has(canonical(skill.path)) && !preferences.disabledSkills.includes(key) : !preferences.disabledSkills.includes(key),
        tokens: skill.promptEnabled === false ? 0 : estimatedTokens(helpers?.skillPrompt?.(skill) ?? `<skill><name>${skill.name}</name><description>${skill.description}</description><location>${skill.path}</location></skill>`), children: [] };
      (skill.module && groupNodes.has(skill.module) ? groupNodes.get(skill.module)!.children : ungrouped).push(node);
    }
    const registered = new Map(pi.getMcpServers().map(server => [server.name, server]));
    const files = fileServers(ctx);
    const servers = new Set([...registered.keys(), ...files.keys(), ...Object.keys(cache.tools), ...Object.values(groups).flatMap(group => group.servers ?? [])]);
    for (const name of servers) {
      const file = files.get(name)?.file;
      const original = files.get(name)?.config ?? registered.get(name)?.config;
      const config = file ? original! : configuredMcp(original ?? { url: "http://127.0.0.1:9" }, preferences.servers[name]);
      const children = Object.values(cache.tools[name] ?? {}).map((tool): ResourceNode => {
        const mode = exposure(config, tool.name);
        return { id: `tool:${name}/${tool.name}`, name: tool.name, kind: "tool", server: name, tool: tool.name, mode, file,
          enabled: mode !== "hidden", tokens: tool.tokens, children: [] };
      });
      const node: ResourceNode = { id: `server:${name}`, name: `${name} — MCP${!children.length ? " (schemas pending)" : !original ? " (not connected)" : ""}`, kind: "server", server: name, file,
        enabled: config.enabled !== false, tokens: estimatedTokens(name + " " + (config.description ?? "") + " codemode deferred"), children };
      const group = Object.entries(groups).find(([, value]) => value.servers?.includes(name))?.[0];
      (group ? groupNodes.get(group)!.children : ungrouped).push(node);
    }
    saveJson(cachePath, cache);
    return [...roots, { id: "ungrouped", name: "Ungrouped", kind: "separator", enabled: true, tokens: 0, children: [] }, ...ungrouped];
  };

  const applyTree = async (before: ResourceNode[], after: ResourceNode[], ctx: ExtensionCommandContext) => {
    const flatten = (nodes: ResourceNode[]): ResourceNode[] => nodes.flatMap(node => [node, ...flatten(node.children)]);
    const old = new Map(flatten(before).map(node => [node.id, node]));
    const changed = flatten(after).filter(node => node.kind !== "separator" &&
      (old.get(node.id)?.enabled !== node.enabled || old.get(node.id)?.mode !== node.mode));
    if (!changed.length) return;
    const needsReload = changed.some(node => node.kind === "skill" || node.kind === "module" || node.file);
    if (!ctx.isIdle()) throw new Error("Wait for the current run before applying resource changes");
    if (needsReload && runningSubagents()) throw new Error("Subagents are running. Changes were not applied: reload would stop them");
    const settings = readSettings();
    const next = resourcePreferences(preferencesPath);
    const groups = catalog();
    const setModule = (node: ResourceNode) => {
      const source = groups[node.name]?.source;
      if (!source) throw new Error("Only declared resource modules can be switched");
      const remembered = settings.huixDisabledModules ?? {};
      if (!remembered || typeof remembered !== "object" || Array.isArray(remembered)) throw new Error("Invalid saved module preferences");
      const index = settings.packages.findIndex(item => sourceOf(item) === source);
      if (node.enabled && index < 0) { settings.packages.push(remembered[node.name] ?? source); delete remembered[node.name]; }
      else if (!node.enabled && index >= 0) { remembered[node.name] = settings.packages[index]; settings.packages.splice(index, 1); }
      settings.huixDisabledModules = remembered;
    };
    for (const node of changed.filter(node => node.kind === "module" && node.enabled)) setModule(node);
    for (const node of changed.filter(node => node.kind === "skill")) {
      setSkillEnabled(settings, node.skill!, node.enabled);
      const key = node.id.slice("skill:".length);
      next.disabledSkills = next.disabledSkills.filter(item => item !== key);
      if (!node.enabled) next.disabledSkills.push(key);
    }
    for (const node of changed.filter(node => node.kind === "module" && !node.enabled)) setModule(node);
    const changedServers = new Set<string>();
    const changedFiles = new Map<string, { mcpServers: Record<string, McpServerConfig>; [key: string]: unknown }>();
    for (const node of changed.filter(node => node.kind === "server" || node.kind === "tool")) {
      const name = node.server!;
      if (node.file) {
        if (lstatSync(node.file).isSymbolicLink()) throw new Error("MCP config is a managed symlink; edit its declarative source instead");
        const document = changedFiles.get(node.file) ?? readJson<{ mcpServers: Record<string, McpServerConfig> }>(node.file);
        const config = document.mcpServers[name];
        if (node.kind === "server") config.enabled = node.enabled;
        else config.toolExposure = { ...config.toolExposure, [node.tool!]: node.enabled ? node.mode ?? "deferred" : "hidden" };
        changedFiles.set(node.file, document);
        continue;
      }
      if (!pi.getMcpServers().some(server => server.name === name)) throw new Error("Enable the server's module before changing its MCP settings");
      const entry = Object.hasOwn(next.servers, name) ? next.servers[name] : {};
      next.servers = { ...next.servers, [name]: entry };
      if (node.kind === "server") entry.enabled = node.enabled;
      else {
        entry.tools ??= {};
        if (node.enabled) {
          const original = pi.getMcpServers().find(server => server.name === name)!.config;
          const mode = node.mode ?? exposure(original, node.tool!);
          entry.tools = { ...entry.tools, [node.tool!]: mode === "hidden" ? "deferred" : mode };
        } else entry.tools = { ...entry.tools, [node.tool!]: "hidden" };
      }
      changedServers.add(name);
    }
    const warning = "Resource changes may change the cached prefix. Already loaded conversation content stays.";
    if (ctx.hasUI) {
      if (!await ctx.ui.confirm("Apply resources", `${warning} ${needsReload ? "Reload and apply?" : "Apply without full reload?"}`)) return;
    } else ctx.ui.notify(warning, "warning");
    if (!needsReload && changedServers.size && !reconfigureMcp) throw new Error("Native MCP controls are not ready; nothing was changed");
    saveJson(preferencesPath, next);
    for (const [path, document] of changedFiles) saveJson(path, document);
    if (needsReload) saveJson(settingsPath, settings);
    preferences = next;
    if (needsReload) { await ctx.reload(); return; }
    await reconfigureMcp?.(ctx);
    ctx.ui.notify("MCP preferences saved; affected servers reconfigured without a full reload", "info");
  };

  pi.registerCommand("modules", {
    description: "Resource folders, skills, MCP tools and estimated initial-context tokens",
    handler: async (args, ctx) => {
      if (!ctx.isIdle() && args.trim()) {
        ctx.ui.notify("Wait for the current run to finish before changing modules", "warning");
        return;
      }
      try {
        const groups = catalog();
        const words = args.trim().split(/\s+/);
        if (["mcp", "tool", "skill", "memory"].includes(words[0])) {
          const nodes = tree(readSettings(), ctx);
          const draft = structuredClone(nodes);
          const flatten = (items: ResourceNode[]): ResourceNode[] => items.flatMap(node => [node, ...flatten(node.children)]);
          const all = flatten(draft);
          if (words[0] === "memory" && words.length === 2 && ["read", "normal"].includes(words[1])) {
            const memory = all.find(node => node.kind === "server" && ["memory", "memory-trial"].includes(node.server ?? ""));
            if (!memory) throw new Error("Memory MCP is not configured");
            memory.enabled = true;
            for (const child of memory.children) {
              child.enabled = words[1] === "read" ? child.tool === "recall" : ["recall", "retain", "invalidate_memory"].includes(child.tool ?? "");
              if (child.enabled) child.mode = "direct";
            }
          } else {
            const kind = words[0] === "mcp" ? "server" : words[0];
            const id = words[0] === "tool" ? `tool:${words[1]}/${words[2]}` : `${kind}:${words[1]}`;
            const node = all.find(node => node.id === id);
            const mode = words.at(-1)!;
            if (!node || words.length !== (words[0] === "tool" ? 4 : 3) ||
                !(words[0] === "tool" ? ["direct", "deferred", "codemode", "hidden"].includes(mode) : ["on", "off"].includes(mode))) {
              throw new Error("Usage: /modules mcp <server> on|off; tool <server> <tool> direct|deferred|codemode|hidden; skill <group/name> on|off; memory read|normal");
            }
            node.enabled = !["hidden", "off"].includes(mode);
            if (node.kind === "tool") node.mode = mode as McpExposure;
          }
          await applyTree(nodes, draft, ctx);
          return;
        }
        let [name, action, extra] = args.trim().split(/\s+/);
        if (!name) {
          const settings = readSettings();
          const nodes = tree(settings, ctx);
          if (!ctx.hasUI || !helpers) {
            const describe = (items: ResourceNode[], indent = ""): string[] => items.flatMap(node => node.kind === "separator" ? ["--- Ungrouped ---"] :
              [`${indent}[${node.enabled ? "x" : " "}] ${node.name} — ≈ ${nodeTokens(node)} tok`, ...describe(node.children, indent + "  ")]);
            ctx.ui.notify(describe(nodes).join("\n"), "info");
            return;
          }
          const draft = structuredClone(nodes);
          const accepted = await ctx.ui.custom<boolean>((tui, theme, _keys, done) => {
            const component = resourceTree(draft, done, { ...helpers, height: () => tui.terminal.rows, theme });
            return { ...component, handleInput(data: string) { component.handleInput(data); tui.requestRender(); } };
          }, { overlay: true, overlayOptions: { anchor: "bottom-center", width: "100%", maxHeight: "100%", margin: { bottom: 1 } } });
          if (accepted) await applyTree(nodes, draft, ctx);
          return;
        }
        if (!name || !Object.hasOwn(groups, name) || extra || (action && action !== "on" && action !== "off")) {
          ctx.ui.notify("Usage: /modules [<module> on|off]; only declared tool modules can be switched", "error");
          return;
        }
         const nodes = tree(readSettings(), ctx);
         const draft = structuredClone(nodes);
         const node = draft.find(node => node.id === `module:${name}`)!;
         const enable = action ? action === "on" : !node.enabled;
         if (enable === node.enabled) {
           ctx.ui.notify(`Module ${name} is already ${enable ? "on" : "off"}`, "info");
           return;
         }
         node.enabled = enable;
         await applyTree(nodes, draft, ctx);
      } catch (error) {
        ctx.ui.notify(String(error), "error");
        return;
      }
    },
  });
  return nativeReady;
}

export default async function modules(pi: ExtensionAPI) {
  const { createMcpExtension, loadSkillsFromDir, formatSkillsForPrompt } = await import("@earendil-works/pi-coding-agent");
  const { matchesKey, truncateToWidth } = await import("@earendil-works/pi-tui");
  await setupModules(pi, {
    matchesKey, truncateToWidth,
    readSkills: dir => existsSync(dir) ? loadSkillsFromDir({ dir, source: dir }).skills.map(skill => ({
      name: skill.name, description: skill.description, path: skill.filePath, promptEnabled: !skill.disableModelInvocation,
    })) : [],
    skillPrompt: entry => {
      const skill: Skill = { name: entry.name, description: entry.description, filePath: entry.path, baseDir: entry.path,
        disableModelInvocation: entry.promptEnabled === false,
        sourceInfo: { path: entry.path, source: "user", scope: "user", origin: "top-level" } };
      return formatSkillsForPrompt([skill]).split("<available_skills>")[1]?.split("</available_skills>")[0] ?? "";
    },
  }, createMcpExtension());
}
