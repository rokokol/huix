import {
  getLanguageFromPath,
  highlightCode,
  type ExtensionAPI,
  type Theme,
  type ToolRenderContext,
} from "@earendil-works/pi-coding-agent";
import { Text, type Component } from "@earendil-works/pi-tui";
import { isAbsolute, relative, resolve } from "node:path";

// Pi paints a diff as whole coloured lines and never highlights their code, so a hunk reads as
// green and red text with no syntax. This renderer keeps Pi's layout and colours each changed line's
// code with the active theme's own `syntax*` tokens, the ones Pi uses for reads and code fences.
//
// The diff is painted in the call component, not in the result: `quiet-tools` drops every result row
// of a collapsed tool, and a diff drawn there would disappear from the transcript
const DIFF_LINE = /^([+-\s])(\s*\d*)\s(.*)$/;
// The sequence that closes a foreground colour inside a highlighted line, and the one that resets
// every attribute; both end a line background as well, so it is re-applied after each
const CLOSES_FG = /\x1b\[(?:0|39)m/g;

/** State kept on one tool row between its call and result passes */
interface RowState {
  text?: Text;
  /** The numbered diff Pi recorded for this edit, stashed when the result arrives */
  diff?: string;
  /** The message of a failed edit, painted in place of a diff */
  error?: string;
}

/** The escape sequences that open and close a colour drawn from a theme token */
function wrap(theme: Theme, token: string): { on: string; off: string } {
  const [on, off] = theme.fg(token, "\u0000").split("\u0000");
  return { on: on ?? "", off: off ?? "" };
}

/** The escape sequences that open and close a background drawn from a theme token */
function background(theme: Theme, token: "toolSuccessBg" | "toolErrorBg"): { on: string; off: string } {
  const [on, off] = theme.bg(token, "\u0000").split("\u0000");
  return { on: on ?? "", off: off ?? "" };
}

/**
 * Paint one side of a hunk: the mark keeps the diff's own colour, the code underneath carries syntax
 * colour over the line's role colour, so the text a grammar leaves bare still reads as changed
 */
function paintCode(
  theme: Theme,
  mark: string,
  number: string,
  content: string,
  language: string | undefined,
  fill: { on: string; off: string },
): string {
  const fg = mark === "+" ? "toolDiffAdded" : "toolDiffRemoved";
  const role = wrap(theme, fg);
  const [code] = highlightCode(content, language);
  // A highlighted token closes its own foreground, which takes the line's colour with it
  const repainted = (code ?? "").replace(CLOSES_FG, (sequence) => sequence + role.on);
  const body = `${role.on}${repainted}${role.off}`;
  return `${theme.fg(fg, mark)}${theme.fg("toolDiffContext", number)} ${fill.on}${body}${fill.off}`;
}

/** Paint Pi's numbered diff: changed lines highlighted, context lines dimmed */
function paintDiff(diff: string, path: string, theme: Theme): string[] {
  const language = getLanguageFromPath(path);
  const added = background(theme, "toolSuccessBg");
  const removed = background(theme, "toolErrorBg");
  const painted: string[] = [];
  for (const raw of diff.split("\n")) {
    const parsed = raw.match(DIFF_LINE);
    if (!parsed) {
      painted.push(theme.fg("toolDiffContext", raw));
      continue;
    }
    const [, mark = " ", number = "", content = ""] = parsed;
    if (mark === " ") {
      painted.push(theme.fg("toolDiffContext", raw));
      continue;
    }
    painted.push(paintCode(theme, mark, number, content, language, mark === "+" ? added : removed));
  }
  return painted;
}

/** The path as the transcript shows it: relative to the working directory when it is below it */
function shownPath(path: string, cwd: string): string {
  const absolute = isAbsolute(path) ? path : resolve(cwd, path);
  const below = relative(cwd, absolute);
  return below.startsWith("..") ? absolute : below;
}

/** Paint the row: the header, then the diff or the failure */
function paintRow(state: RowState, args: Record<string, unknown> | undefined, theme: Theme, cwd: string): void {
  const path = typeof args?.path === "string" ? args.path : typeof args?.file_path === "string" ? args.file_path : "";
  const header = `${theme.fg("toolTitle", theme.bold("edit"))} ${theme.fg("accent", shownPath(path, cwd))}`;
  const body = state.error
    ? [theme.fg("error", state.error)]
    : state.diff
      ? paintDiff(state.diff, path, theme)
      : [];
  state.text?.setText([header, ...body].join("\n"));
}

export default function diffHighlight(pi: ExtensionAPI): void {
  pi.registerToolRenderer((toolName, next) => {
    // Every other tool keeps what the rest of the chain would draw for it
    if (toolName !== "edit") return next();
    return {
      renderCall(args, theme, context: ToolRenderContext<RowState>) {
        const state = context.state as RowState;
        const text = state.text ?? new Text("", 0, 0);
        state.text = text;
        paintRow(state, args as Record<string, unknown>, theme, context.cwd);
        return text;
      },
      renderResult(result, _options, theme, context: ToolRenderContext<RowState>): Component {
        const state = context.state as RowState;
        const details = result.details as { diff?: unknown } | undefined;
        state.error = context.isError ? textOf(result.content) || "edit failed" : undefined;
        // The patch is frozen once the result lands, so a repeat of the same string repaints nothing
        if (typeof details?.diff === "string") state.diff = details.diff;
        paintRow(state, context.args as Record<string, unknown>, theme, context.cwd);
        // The call component already carries the diff, so the result row stays empty
        return new Text("", 0, 0);
      },
    };
  });
}

/** The first text block of a tool result, as the failure message */
function textOf(content: unknown): string {
  if (!Array.isArray(content)) return "";
  for (const block of content) {
    if (block && typeof block === "object" && "type" in block && block.type === "text") {
      const value = (block as { text?: unknown }).text;
      if (typeof value === "string") return value;
    }
  }
  return "";
}
