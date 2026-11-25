import { spawn } from "node:child_process";
import { createInterface } from "node:readline";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { type ArtifactWake, wakeRoute } from "./open-artifact-routing.ts";

type Tool = { name: string; description: string; inputSchema: Parameters<typeof Type.Unsafe>[0] };
type Pending = { resolve: (result: unknown) => void; reject: (error: Error) => void };
type Caller = { session: string; workspace: string };

// The daemon speaks JSON-RPC 2.0 over the stdio bridge, so an extension holds one spawned process
// rather than a socket; the bridge reads the token from daemon.json itself
function bridge(receive: (wake: ArtifactWake) => string, inbox: (session: string, wakes: ArtifactWake[]) => void) {
  const child = spawn("open-artifact", ["harness", "--stdio", "--harness", "pi"], {
    stdio: ["pipe", "pipe", "ignore"],
  });
  const lines = createInterface({ input: child.stdout });
  const pending = new Map<number, Pending>();
  let nextId = 0;
  let closed = false;

  function stop(error = new Error("Open Artifact bridge closed")) {
    if (closed) return;
    closed = true;
    lines.close();
    child.stdin.end();
    for (const call of pending.values()) call.reject(error);
    pending.clear();
  }

  function send(fields: object) {
    child.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", ...fields })}\n`);
  }

  child.on("error", stop);
  child.stdin.on("error", stop);
  child.once("close", () => stop());
  lines.on("line", (line) => {
    try {
      const message = JSON.parse(line);
      if (message.method === "wake.deliver") {
        let status = "failed";
        try {
          status = receive(message.params);
        } finally {
          send({ id: message.id, result: { status } });
        }
      } else if (message.method === "bridge.reattached") {
        inbox(message.params.params.session, message.params.inbox);
      } else if (typeof message.id === "number") {
        const call = pending.get(message.id);
        pending.delete(message.id);
        if (message.error) call?.reject(new Error(message.error.message));
        else call?.resolve(message.result);
      }
    } catch (error) {
      stop(error instanceof Error ? error : new Error(String(error)));
    }
  });

  function request<T>(method: string, params: object): Promise<T> {
    if (closed) return Promise.reject(new Error("Open Artifact bridge closed"));
    const id = ++nextId;
    return new Promise<T>((resolve, reject) => {
      // A daemon that cannot answer must not leave a tool call waiting for the rest of the session
      const timeout = setTimeout(() => {
        pending.delete(id);
        reject(new Error(`Open Artifact timed out: ${method}`));
      }, 30000);
      pending.set(id, {
        resolve(result) {
          clearTimeout(timeout);
          resolve(result as T);
        },
        reject(error) {
          clearTimeout(timeout);
          reject(error);
        },
      });
      send({ id, method, params });
    });
  }

  return {
    request,
    stop,
    get closed() {
      return closed;
    },
  };
}

export default function (pi: ExtensionAPI) {
  let transport: ReturnType<typeof bridge> | undefined;
  let connection: Promise<{ transport: ReturnType<typeof bridge>; caller: Caller }> | undefined;
  const registered = new Set<string>();

  function attach(ctx: ExtensionContext) {
    if (transport?.closed) connection = undefined;
    return (connection ??= (async () => {
      const caller: Caller = { session: ctx.sessionManager.getSessionId(), workspace: ctx.cwd };

      function receive(wake: ArtifactWake) {
        const route = wakeRoute(caller.session, wake);
        if (route === "failed" || wake.text === undefined) return "failed";
        // Only the artifact's owner speaks as the person; anyone else reaches the agent as a notice
        if (route === "turn") pi.sendUserMessage(wake.text, { deliverAs: "followUp" });
        else {
          pi.sendMessage(
            { customType: "open-artifact-notice", content: wake.text, display: true },
            { deliverAs: "followUp" },
          );
        }
        return "delivered";
      }

      function inbox(session: string, wakes: ArtifactWake[] = []) {
        if (session === caller.session) for (const wake of wakes) receive({ ...wake, session });
      }

      const link = (transport = bridge(receive, inbox));
      try {
        await link.request("hello", {
          harness: "pi",
          caps: { wake: { resume: false }, tools: "native", agentName: "Pi" },
        });
        const attached = await link.request<{ inbox: ArtifactWake[] }>("session.attach", caller);
        // The schemas belong to the daemon, so the extension carries no second copy of them
        const { tools } = await link.request<{ tools: Tool[] }>("tools.list", {});
        for (const tool of tools) {
          if (registered.has(tool.name)) continue;
          registered.add(tool.name);
          pi.registerTool({
            name: tool.name,
            label: tool.name,
            description: tool.description,
            parameters: Type.Unsafe<Record<string, unknown>>(tool.inputSchema),
            async execute(_callId, args, _signal, _onUpdate, active) {
              const live = await attach(active);
              const result = await live.transport.request("tools.call", {
                name: tool.name,
                arguments: args,
                caller: live.caller,
              });
              return { content: [{ type: "text", text: JSON.stringify(result) }], details: result };
            },
          });
        }
        inbox(caller.session, attached.inbox);
        return { transport: link, caller };
      } catch (error) {
        link.stop();
        throw error;
      }
    })());
  }

  pi.on("session_shutdown", () => transport?.stop());
  pi.registerCommand("open-artifact-connect", {
    description: "Connect this Pi session to Open Artifact",
    handler: async (_args, ctx) => {
      await attach(ctx);
      ctx.ui.notify("Open Artifact is connected to this session", "info");
    },
  });
}
