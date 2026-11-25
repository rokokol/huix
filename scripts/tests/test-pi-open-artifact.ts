import assert from "node:assert/strict";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

type Route = (session: string, wake: { session?: string | null; text?: string; source?: { from?: { kind?: string } } }) => string;

// The extension imports its router by a relative path, so the module is given here rather than
// imported from beside this file, which lives in the store on its own
const modulePath = resolve(process.argv[2] ?? "");
const { wakeRoute } = (await import(pathToFileURL(modulePath).href)) as { wakeRoute: Route };

const wake = (session: string, kind?: string) => ({ session, text: "Please revise the title", source: { from: { kind } } });

// Only the owner can start a turn in the session the artifact belongs to
assert.equal(wakeRoute("attached", wake("attached", "owner")), "turn");
for (const kind of ["collaborator", "system", undefined]) {
  assert.equal(wakeRoute("attached", wake("attached", kind)), "notice");
}
assert.equal(wakeRoute("attached", wake("other", "owner")), "failed");
assert.equal(wakeRoute("attached", { ...wake("attached", "owner"), text: "" }), "failed");
console.log("open-artifact routing: ok");
