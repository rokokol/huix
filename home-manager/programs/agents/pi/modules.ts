import { randomUUID } from "node:crypto";
import { readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

type Package = string | { source: string; [key: string]: unknown };
const sourceOf = (item: Package) => typeof item === "string" ? item : item.source;

export default function modules(pi: ExtensionAPI) {
  const configured = process.env.PI_CODING_AGENT_DIR;
  const directory = configured?.startsWith("~/")
    ? join(homedir(), configured.slice(2)) : configured || join(homedir(), ".pi/agent");
  const settingsPath = join(directory, "settings.json");
  pi.registerCommand("modules", {
    description: "Enable or disable a complete tool module, including its MCP servers and skills",
    handler: async (args, ctx) => {
      if (!ctx.isIdle()) {
        ctx.ui.notify("Wait for the current run to finish before changing modules", "warning");
        return;
      }
      try {
        const catalog: Record<string, { source: string; description: string }> =
          JSON.parse(readFileSync(join(directory, "modules.json"), "utf8"));
        const readSettings = () => {
          const settings = JSON.parse(readFileSync(settingsPath, "utf8"));
          if (!settings || typeof settings !== "object" || Array.isArray(settings) ||
              !Array.isArray(settings.packages) || !settings.packages.every((item: unknown) =>
                typeof item === "string" || (item && typeof item === "object" && "source" in item && typeof item.source === "string"))) {
            throw new Error("Invalid Pi package settings; nothing was changed");
          }
          return settings as { packages: Package[]; huixDisabledModules?: Record<string, Package>;
            [key: string]: unknown };
        };
        let [name, action, extra] = args.trim().split(/\s+/);
        if (!name) {
          const settings = readSettings();
          const entries = Object.entries(catalog);
          const labels = entries.map(([key, entry]) =>
            `${settings.packages.some(item => sourceOf(item) === entry.source) ? "[x]" : "[ ]"} ${key} — ${entry.description}`);
          if (!ctx.hasUI) {
            ctx.ui.notify(`${labels.join("\n")}\nUsage: /modules <name> on|off`, "info");
            return;
          }
          const picked = await ctx.ui.select("Toggle a module (MCP + skills; reloads immediately)", labels);
          if (!picked) return;
          name = entries[labels.indexOf(picked)]?.[0];
        }
        if (!name || !Object.hasOwn(catalog, name) || extra || (action && action !== "on" && action !== "off")) {
          ctx.ui.notify("Usage: /modules [<module> on|off]; only declared tool modules can be switched", "error");
          return;
        }
        const settings = readSettings();
        const source = catalog[name].source;
        const index = settings.packages.findIndex(item => sourceOf(item) === source);
        const enable = action ? action === "on" : index < 0;
        if (enable === (index >= 0)) {
          ctx.ui.notify(`Module ${name} is already ${enable ? "on" : "off"}`, "info");
          return;
        }
        const remembered = settings.huixDisabledModules ?? {};
        if (!remembered || typeof remembered !== "object" || Array.isArray(remembered)) {
          throw new Error("Invalid saved module preferences; nothing was changed");
        }
        if (enable) {
          const previous = remembered[name];
          settings.packages.push(previous && sourceOf(previous) === source ? previous : source);
          delete remembered[name];
        } else {
          remembered[name] = settings.packages[index];
          settings.packages = settings.packages.filter(item => sourceOf(item) !== source);
        }
        settings.huixDisabledModules = remembered;
        const temporary = `${settingsPath}.${randomUUID()}`;
        writeFileSync(temporary, JSON.stringify(settings, null, 2) + "\n", { mode: 0o600, flag: "wx" });
        renameSync(temporary, settingsPath);
        ctx.ui.notify(`Module ${name}: ${enable ? "on" : "off"}. Reloading MCP servers and skills`, "info");
      } catch (error) {
        ctx.ui.notify(String(error), "error");
        return;
      }
      await ctx.reload();
    },
  });
}
