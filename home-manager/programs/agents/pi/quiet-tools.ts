import { ToolExecutionComponent, type ExtensionAPI, type Theme } from "@earendil-works/pi-coding-agent";
import { stripTerminalSequences, Text, truncateToWidth, type Component } from "@earendil-works/pi-tui";

// A collapsed tool row is one grey line that says what was called: no panel, no colour that reports
// how the call went, no preview of its output. Ctrl+O expands a row, and an expanded row is Pi's own
// rendering down to the pending/success/error panel
//
// `edit` and `write` keep Pi's row in both states: their collapsed content is the diff itself, and
// the diff is what the transcript is read for
const KEPT_ROWS = new Set(["edit", "write"]);
// The one mark a collapsed row keeps: that the call failed
const FAILED = "✗";
// Marks `ToolExecutionComponent.updateDisplay`, so a reload patches the prototype once
const PATCH = Symbol.for("huix.quiet-tools.patch");

/** The box `ToolExecutionComponent` draws a row in, as far as this extension touches it */
interface RowBox {
  paddingY: number;
  children: unknown[];
  invalidateCache(): void;
  removeChild(child: unknown): void;
  setBgFn(fn: (text: string) => string): void;
}

/** The row component, as far as this extension touches it */
interface Row {
  expanded: boolean;
  contentBox?: RowBox;
  updateDisplay(): void;
}

/** The parts of Pi's render context this extension reads */
interface RowContext {
  expanded: boolean;
  isError: boolean;
  outputPad: number;
}

export default function quietTools(pi: ExtensionAPI): void {
  pi.registerToolRenderer((toolName, next) => {
    const base = next();
    // Captured, because a narrowed property is not narrowed inside the closures below
    const drawCall = base?.renderCall;
    const drawResult = base?.renderResult;
    // A row Pi draws generically, or one that frames itself, stays Pi's
    if (!base || !drawCall || !drawResult || base.renderShell === "self") return base;
    if (KEPT_ROWS.has(toolName)) return base;
    return {
      renderShell: base.renderShell,
      renderCall(args, theme, context) {
        if (context.expanded) return drawCall(args, theme, context);
        return quietRow(drawCall(args, theme, context), theme, context);
      },
      renderResult(result, options, theme, context) {
        if (options.expanded) return drawResult(result, options, theme, context);
        // Removed from the panel by `quietPanels`, so the collapsed row is the call alone
        return new Text("", 0, 0);
      },
    };
  });
  quietPanels();
}

/**
 * A tool's own call line, flattened to one grey line that fits the row. Flattening drops the
 * hyperlink a path carries, which is the price of one colour for the whole row
 */
function quietRow(component: Component, theme: Theme, context: RowContext): Component {
  const mark = context.isError ? `${theme.fg("error", FAILED)} ` : "";
  const width = Math.max(20, (process.stdout.columns ?? 100) - 2 * context.outputPad - (mark ? 2 : 0));
  let line: string;
  try {
    // A rendered line is padded to the width, and the padding is what would wrap it again
    line = stripTerminalSequences(component.render(width)[0] ?? "").trimEnd();
  } catch {
    // A renderer that cannot be measured keeps its own component rather than breaking the row
    return component;
  }
  return new Text(mark + theme.fg("muted", truncateToWidth(line, width)), 0, 0);
}

/** A collapsed row loses the panel colour and the vertical padding, and nothing else */
function quietPanels(): void {
  const proto = ToolExecutionComponent.prototype as unknown as Row & { [PATCH]?: () => void };
  if (proto[PATCH]) return;
  const original = proto.updateDisplay;
  const padding = new WeakMap<Row, number>();
  proto.updateDisplay = function patched(this: Row) {
    original.call(this);
    const box = this.contentBox;
    if (!box) return;
    const saved = padding.get(this) ?? box.paddingY;
    padding.set(this, saved);
    box.paddingY = this.expanded ? saved : 0;
    box.invalidateCache();
    if (this.expanded) return;
    box.setBgFn((text) => text);
    // The call is the first child; the empty result renderer adds the second
    while (box.children.length > 1) box.removeChild(box.children[box.children.length - 1]);
  };
  proto[PATCH] = original;
}
