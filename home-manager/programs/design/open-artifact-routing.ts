export interface ArtifactWake {
  session?: string | null;
  text?: string;
  source?: { from?: { kind?: string } };
}

export function wakeRoute(session: string, wake: ArtifactWake) {
  if (wake.session !== session || typeof wake.text !== "string" || !wake.text.trim()) return "failed";
  return wake.source?.from?.kind === "owner" ? "turn" : "notice";
}
