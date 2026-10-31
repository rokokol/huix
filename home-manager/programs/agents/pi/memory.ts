import { readFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function memory(pi: ExtensionAPI) {
  pi.registerMcpServer("memory", {
    url: "@url@",
    headers: { Authorization: `Bearer ${readFileSync("@tokenFile@", "utf8").trim()}` },
    description: "Shared long-term memory. retain queues storage; accepted is not completed. invalidate_memory reversibly retires a fact from recall. Extra audit/reflection tools are opt-in through /modules.",
    timeout: 180,
    exposure: "hidden",
    toolExposure: {
      retain: "direct",
      recall: "direct",
      invalidate_memory: "direct",
    },
  });
}
