---
name: new-session
description: Replace this session with a fresh one, with an empty context. Use when the owner asks for a new session, a clean start, a cleared context or a restart, in any words — "новая сессия", "начни заново", "очисти контекст", "перезапустись", "start over"
---

# new-session

This session runs in tmux under a systemd unit. When the tmux server ends, the unit starts a new session with an empty context, about five seconds later. Nothing in this session runs after the server ends

1. Save to memory anything from this session that the next one needs, as the memory rules say
2. Reply on the channel the request came from: a new session starts in a few seconds. This session cannot answer after the next step
3. Run `tmux kill-server`. In this session `$TMUX` names its own server, so the bare command ends this one and no other
