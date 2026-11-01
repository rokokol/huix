import { readFileSync } from "node:fs";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function memory(pi: ExtensionAPI) {
  pi.registerMcpServer("memory", {
    url: "@url@",
    headers: { Authorization: `Bearer ${readFileSync("@tokenFile@", "utf8").trim()}` },
    description: "Shared long-term memory. retain queues storage; accepted is not completed. invalidate_memory reversibly retires a fact from recall. get_mental_model reads a synthesized working brief by id. Extra audit/reflection tools are opt-in through /modules.",
    timeout: 180,
    exposure: "hidden",
    toolExposure: {
      retain: "direct",
      recall: "direct",
      get_mental_model: "direct",
      invalidate_memory: "direct",
    },
  });
}
