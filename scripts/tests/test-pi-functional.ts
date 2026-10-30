import assert from "node:assert/strict";
import { createServer } from "node:http";
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";
import { setTimeout as delay } from "node:timers/promises";
import type { AddressInfo } from "node:net";
import type { JsonAgentSessionEvent, RpcClient as RpcClientType } from "@earendil-works/pi-coding-agent";

const [piRoot, extensionsRoot] = process.argv.slice(2);
const { RpcClient } = await import(pathToFileURL(join(piRoot, "dist/modes/rpc/rpc-client.js")).href) as { RpcClient: typeof RpcClientType };
const root = mkdtempSync(join(tmpdir(), "pi-functional-"));
const agent = join(root, ".pi/agent");
const extensions = join(extensionsRoot, "node_modules");
mkdirSync(join(agent, "intercom"), { recursive: true });
writeFileSync(join(agent, "settings.json"), JSON.stringify({
  packages: [join(extensions, "@tintinweb/pi-subagents"), join(extensions, "pi-intercom")],
  enableInstallTelemetry: false, enableAnalytics: false, defaultProjectTrust: "never",
}));
writeFileSync(join(agent, "intercom/config.json"), JSON.stringify({
  brokerCommand: process.execPath, brokerArgs: [join(extensions, "tsx/dist/cli.mjs")],
  inboundTrigger: "never",
}));
let childFinished = false;
let releaseChild: () => void;
const childRelease = new Promise<void>(resolve => { releaseChild = resolve; });
const requests: { model: string; path: string | undefined }[] = [];
const server = createServer(async (request, response) => {
  try {
    let body = "";
    for await (const chunk of request) body += chunk;
    const data: { model: string; messages: { role: string; content: string | { type: string; text?: string }[] }[] } = JSON.parse(body);
    requests.push({ model: data.model, path: request.url });
    const last = data.messages.at(-1);
    assert(last, "Fixture request has no messages");
    const text = typeof last.content === "string" ? last.content :
      (last.content ?? []).filter(part => part.type === "text").map(part => part.text).join("\n");
    let tool: { name: string; arguments: Record<string, unknown> } | undefined;
    if (last.role === "user" && text.startsWith("PROBE_CALL ")) tool = JSON.parse(text.slice(11));
    if (data.model === "child") {
      await childRelease;
      childFinished = true;
    }
    const id = `fixture-${requests.length}`;
    response.writeHead(200, { "Content-Type": "text/event-stream" });
    const chunk = (delta: Record<string, unknown>, finish_reason: string | null = null) => response.write(`data: ${JSON.stringify({
      id, object: "chat.completion.chunk", created: 1, model: data.model,
      choices: [{ index: 0, delta, finish_reason }],
    })}\n\n`);
    chunk({ role: "assistant", ...(tool ? { tool_calls: [{
      index: 0, id: `call-${requests.length}`, type: "function",
      function: { name: tool.name, arguments: JSON.stringify(tool.arguments) },
    }] } : { content: data.model === "child" ? "CHILD_DONE" : "FIXTURE_OK" }) });
    chunk({}, tool ? "tool_calls" : "stop");
    response.end("data: [DONE]\n\n");
  } catch (error) {
    response.writeHead(500);
    response.end(String(error));
  }
});
await new Promise<void>(resolve => server.listen(0, "127.0.0.1", resolve));
const baseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}/v1`;
writeFileSync(join(agent, "models.json"), JSON.stringify({ providers: Object.fromEntries(
  ["main", "child"].map(name => [`fixture-${name}`, {
    baseUrl, api: "openai-completions", apiKey: "fixture-only",
    models: [{ id: name, reasoning: false, contextWindow: 32000, maxTokens: 1000 }],
  }]),
) }));
const clients = ["probe-one", "probe-two"].map(name => new RpcClient({
  cliPath: join(piRoot, "dist/bundle/cli.js"),
  cwd: root, env: { HOME: root, PI_CODING_AGENT_DIR: agent, PI_TELEMETRY: "0", PI_OFFLINE: "1" },
  provider: "fixture-main", model: "main",
  args: ["--offline", "--no-session", "--no-context-files", "--no-skills", "--thinking", "off", "--name", name],
}));
const observed: JsonAgentSessionEvent[] = [];
try {
  for (const client of clients) {
    client.onEvent(event => observed.push(event));
    await client.start();
    const commands = await client.getCommands();
    assert(commands.some(command => command.name === "agents"));
    assert(commands.some(command => command.name === "intercom"));
  }
  const call = (name: string, args: Record<string, unknown>) => clients[0].promptAndWait(
    "PROBE_CALL " + JSON.stringify({ name, arguments: args }), undefined, 15000,
  );
  const listed = await call("intercom", { action: "list" });
  assert(JSON.stringify(listed).includes("probe-two"), "Intercom did not discover the second live session");
  console.log("PASS: real Pi sessions discover each other through Intercom");
  const sent = await call("intercom", { action: "send", to: "probe-two", message: "SYNTHETIC_INTERCOM_MARKER" });
  assert(!sent.some(event => event.type === "tool_execution_end" && event.isError), JSON.stringify(sent));
  const received = await clients[1].getMessages();
  assert(JSON.stringify(received).includes("SYNTHETIC_INTERCOM_MARKER"), "Intercom message was not received");
  console.log("PASS: inter-session delivery reaches the recipient transcript");
  const spawned = await call("Agent", {
    subagent_type: "general-purpose", name: "probe-child", description: "Synthetic background probe",
    prompt: "Return CHILD_DONE", model: "fixture-child/child", run_in_background: true, isolated: true,
  });
  const result = spawned.find(event => event.type === "tool_execution_end" && event.toolName === "Agent");
  assert(result?.type === "tool_execution_end" && !result.isError, JSON.stringify(spawned));
  assert(!childFinished, "Background Agent waited for its child to finish");
  await clients[0].promptAndWait("Answer FIXTURE_OK while the child is running", undefined, 15000);
  assert(!childFinished, "The parent could not answer independently of the child");
  releaseChild!();
  const joined = await call("get_subagent_result", { agent_id: "probe-child", wait: true });
  const answer = joined.find(event => event.type === "tool_execution_end" && event.toolName === "get_subagent_result");
  assert(answer?.type === "tool_execution_end" && !answer.isError && JSON.stringify(answer.result).includes("CHILD_DONE"), JSON.stringify(joined));
  assert(requests.some(request => request.model === "main"));
  assert(requests.some(request => request.model === "child"));
  console.log("PASS: background child answers through its own provider while the parent remains responsive");
} finally {
  releaseChild!();
  writeFileSync(join(root, "events.json"), JSON.stringify(observed, null, 2));
  for (const client of clients) await client.stop();
  await Promise.race([
    new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve())),
    delay(2000).then(() => server.closeAllConnections()),
  ]);
  const pidFile = join(agent, "intercom/broker.pid");
  if (existsSync(pidFile)) {
    const pid = Number(readFileSync(pidFile, "utf8"));
    try { process.kill(pid, "SIGTERM"); } catch (error) { if ((error as NodeJS.ErrnoException).code !== "ESRCH") throw error; }
  }
  console.log(`Synthetic probe logs: ${root}`);
}
