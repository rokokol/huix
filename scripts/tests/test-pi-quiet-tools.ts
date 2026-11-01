import assert from "node:assert/strict";
import { copyFileSync, mkdirSync, mkdtempSync, symlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import type { ExtensionAPI, ToolRendererResolver, ToolRenderers } from "@earendil-works/pi-coding-agent";

// The extension imports Pi by name, so it is read from beside a `node_modules` that points at the
// same Pi this test measures: one copy of the components, and one prototype patch
const extensionSource = resolve(process.argv[2] ?? "");
const piRoot = resolve(process.argv[3] ?? "");
const root = mkdtempSync(join(tmpdir(), "pi-quiet-tools-"));
const modules = join(root, "node_modules", "@earendil-works");
mkdirSync(modules, { recursive: true });
symlinkSync(piRoot, join(modules, "pi-coding-agent"), "dir");
symlinkSync(join(piRoot, "node_modules", "@earendil-works", "pi-tui"), join(modules, "pi-tui"), "dir");
const extensionCopy = join(root, "quiet-tools.ts");
copyFileSync(extensionSource, extensionCopy);

const importFrom = (path: string) => import(pathToFileURL(path).href) as Promise<Record<string, any>>;
const pi = await importFrom(join(piRoot, "dist/index.js"));
const tui = await importFrom(join(piRoot, "node_modules", "@earendil-works", "pi-tui", "dist/index.js"));
const themeModule = await importFrom(join(piRoot, "dist/modes/interactive/theme/theme.js"));
const { default: quietTools } = (await importFrom(extensionCopy)) as { default: (pi: ExtensionAPI) => void };
// The panel background an expanded row is drawn on, and the grey a collapsed one uses, are Pi's own
// theme, so the expectations are read from it rather than spelled in SGR codes
themeModule.initTheme("dark");
const theme = themeModule.theme as { fg(token: string, text: string): string };
const grey = (text: string) => theme.fg("muted", text);
const context = (expanded: boolean, isError = false) => ({
  args: {}, toolCallId: "call-1", invalidate: () => {}, lastComponent: undefined, state: {},
  cwd: root, executionStarted: true, argsComplete: true, isPartial: false, expanded, showImages: false,
  isError, durationMs: 10, outputPad: 1,
});

/** The renderers a tool declares, in the shape a resolver hands back to Pi */
const toolRenderers = (name: string, call: string[], result: string[]): ToolRenderers => ({
  renderCall: (_args, renderTheme) =>
    new tui.Text([renderTheme.fg("toolTitle", call[0] ?? name), ...call.slice(1)].join("\n"), 0, 0),
  renderResult: (_result, _options, renderTheme) =>
    new tui.Text(result.map((line) => renderTheme.fg("muted", line)).join("\n"), 0, 0),
});

/** A row renders padded to the terminal width, which no assertion cares about */
const renderedLines = (instance: { render(width: number): string[] }) =>
  instance.render(80).map((line) => line.trimEnd());

let resolver!: ToolRendererResolver;
quietTools({ registerToolRenderer: (fn: ToolRendererResolver) => {
  resolver = fn;
} } as unknown as ExtensionAPI);
assert.equal(typeof resolver, "function", "the extension registers a tool renderer");

const row = (name: string, renderers: ToolRenderers, isError = false) => {
  const instance = new pi.ToolExecutionComponent(
    name, "call-1", { command: "git status" }, {}, renderers, { requestRender: () => {} }, root,
  );
  const result = { content: [{ type: "text", text: "first\nsecond\nthird" }], details: {} };
  instance.updateResult(isError ? { ...result, isError: true } : result, false);
  return instance as {
    render(width: number): string[];
    setExpanded(expanded: boolean): void;
  };
};

// A row Pi keeps to itself: `edit` draws the diff, and Pi's own framing with it
{
  const base = toolRenderers("edit", ["edit old.ts"], ["new"]);
  assert.equal(resolver("edit", () => base), base, "an edit row keeps Pi's renderers");
}

// A collapsed row: one grey line, no panel colour, nothing of the output
{
  const base = toolRenderers("bash", ["bash git status"], ["first", "second", "third"]);
  const rendered = resolver("bash", () => base) ?? base;
  const instance = row("bash", rendered);
  const lines = renderedLines(instance);
  assert.deepEqual(lines, ["", ` ${grey("bash git status")}`], "one grey line and the row's spacer");
  assert.ok(lines.every((line) => !line.includes("\x1b[48;")), "a collapsed row has no panel colour");
  assert.ok(!lines.join("").includes("first"), "a collapsed row hides the output");

  instance.setExpanded(true);
  const expanded = renderedLines(instance);
  assert.ok(expanded.join("\n").includes("first"), "an expanded row shows the output");
  assert.ok(expanded.some((line) => line.includes("\x1b[48;")), "an expanded row keeps its panel colour");
  assert.ok(expanded.length > lines.length, "an expanded row is taller than the collapsed one");
}

// A row whose own renderer draws several lines collapses to the first one
{
  const base = toolRenderers("bash", ["bash one", "second line"], ["out"]);
  const instance = row("bash", resolver("bash", () => base) ?? base);
  const lines = renderedLines(instance);
  assert.equal(lines.length, 2, "a multi-line call still collapses to one line");
  assert.ok(lines[1]?.includes("bash one"));
  assert.ok(!lines[1]?.includes("second line"));
}

// A failed call keeps the one mark that survives collapsing
{
  const base = toolRenderers("bash", ["bash false"], ["boom"]);
  const instance = row("bash", resolver("bash", () => base) ?? base, true);
  assert.ok(renderedLines(instance)[1]?.startsWith(` ${theme.fg("error", "✗")} ${grey("bash false")}`), "a failed row is marked");
}

// The panel padding comes back when a row expands, and goes again when it collapses
{
  const base = toolRenderers("bash", ["bash one"], ["out"]);
  const instance = row("bash", resolver("bash", () => base) ?? base);
  instance.setExpanded(true);
  assert.ok(renderedLines(instance)[1]?.includes("\x1b[48;"), "an expanded row keeps the panel padding");
  instance.setExpanded(false);
  assert.deepEqual(renderedLines(instance).slice(0, 2), ["", ` ${grey("bash one")}`], "collapsing drops the padding again");
}

// A tool Pi has no renderers for keeps Pi's generic row
{
  assert.equal(resolver("mystery", () => undefined), undefined, "a bare tool keeps Pi's generic row");
}

console.log("quiet-tools: every assertion held");
