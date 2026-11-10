# Pi

[![huix](https://img.shields.io/badge/huix-up-222222?style=flat)](../../README.md)

The settings of pi, its extensions and the definitions of its agents are gathered here. The skills and the MCP servers come from the shared registry; `/modules` shows them as a tree and lets you change a group or a single resource

The available OpenRouter models and the allowed hosts come from [ai-models.nix](../../../../lib/ai-models.nix), which Hermes shares. The list of chat models narrows the model menu, and `/hoster` picks the route inside the allowed set. The privacy settings hold whatever host is chosen

The settings of the interface stay editable, and the keys and the Codex login never enter the Nix store. The system half, which declares the secret, is in [the pi module](../../../../nixos/services/ai/pi/README.md)

## Resources and memory

In `/modules` a group folder holds the skills and the MCP servers, and a server opens down to its tools. The resources outside the groups sit after a separator. Looking changes nothing; the changes apply together with Enter, and Esc drops them. The help in the window names the switch of availability, of the way a tool is declared and of the memory modes

Beside each resource stands an approximate starting cost of its context, and beside a disabled one the cost it would add if switched on. That is an estimate from the descriptions and the known schemas, not a bill from the provider and not the size of the whole session; an unknown schema carries a question mark. Switching off does not remove the text already loaded into the history. A change may affect the prefix cache, and pi warns about that before it applies

For an MCP server from an extension the change applies without a full reload of the session. A change of the groups, of the skills or of the file-based MCP configuration needs a reload, and a running subagent forbids it, since the reload would stop that subagent. An MCP setting that Nix owns changes in the declarative source, never through the menu

The [Hindsight memory](../../../../nixos/services/ai/hindsight/README.md) shared with Hermes is reachable over MCP. The normal mode opens the usual operations of the memory, and read keeps the search and the reading of the synthesised brief of the owner. That is a choice of the tools the client offers, not a separate right on the server: the holder of the API token still reaches the hidden operations outside this client. The brief is read with `get_mental_model` by its id, and the instructions of the agent name the id rather than the code of the client

## The shared folder and the local state

[shared.nix](shared.nix) pulls in the mutable shared instructions, the agents of its own and the prompts from the pi-shared folder. When the local and the shared copy of `AGENTS.md` differ, a move between hosts needs them merged by hand: activation replaces neither

The sync of the shared folder passes only the instructions, the agents, the prompts, the chosen user preferences and the state of the skills: the drafts, the sent items and the standing permissions of contributing live there, so that a move between hosts does not lose them. The authentication, the sessions, the local choice of resources and hosts, the generated configuration, the caches and the logs never mix between the work hosts. [backup.nix](backup.nix) declares a separate copy of the safe part of the local state of each host

## The visible plan of the work

The model keeps the checklist of the current work with the `todo` tool: it creates the steps, marks the one in progress and closes it after it has checked the result. The widget above the input shows the progress, and `/todos` shows the whole list. The state comes back from the branch of the session after a reload and a resumed conversation; it is neither a separate task database nor a proof that the work succeeded without a check

The standing personal tasks stay in Super Productivity. The checklist of pi never moves there by itself

## Messages during the work

Enter sends a refinement to the nearest boundary of the work, Alt+Enter puts the message after the current work, and Esc interrupts it. Alt+↑ returns the waiting messages to the editor. Shift+Enter or Ctrl+J inserts a newline; `/hotkeys` shows the bindings in force

A subagent can work in the background and report to the main session. Ctrl+B moves a running foreground subagent into the background, with no separate plugin for it. Inside tmux the chord first goes through the tmux prefix

## Extensions

The third-party extensions are listed with their pinned versions in [the manifest](extensions/package.json), and the dependencies in the lock file beside it

| Extension | Purpose |
| --- | --- |
| `@juicesharp/rpiv-todo` | The checklist of the current work and the live progress above the input; `/todos` shows the whole list |
| `@tintinweb/pi-subagents` | Independent background subagents, watched and driven through `/agents` |
| `pi-bg-bash` | Background shell commands, a running command moved with Ctrl+Shift+B, its output and control through `/bg` |
| `pi-intercom` | Messages between the sessions |
| `@narumitw/pi-btw` | A side question without interrupting the main work |
| `@narumitw/pi-goal` | Continued work on a goal on the model of the session |
| `@narumitw/pi-usage` | The quota statistics of the provider it can reach |
| `@nicknisi/pi-heads-up` | Background remarks about the progress |
| `@mrclrchtr/supi-ask-user` | Questions with options, a preview and a multiple choice |
| `@mrclrchtr/supi-cache` | The control of the context cache |
| `pi-editor-selection` | Selection and editing of text in the input |
| `pi-multi-pass` | Several models for the analysis and the review of a task |

A background command runs exactly like an ordinary one. The model may call `bash` with `background: true` itself; only the subagent extension does the delegating

## Extensions of my own

- [hoster.ts](hoster.ts) narrows the OpenRouter catalogue to the configured models, checks the privacy policy and keeps the chosen allowed host through `/hoster`
- [modules.ts](modules.ts) drives the resource tree through the stock extension of pi, keeping the user filters and protecting the extensions that must stay
- [memory.ts](memory.ts) connects the shared memory with an API token of its own, and never puts that token into the generated configuration
- [quiet-tools.ts](quiet-tools.ts) folds the line of a tool call into one grey line with a preview under Ctrl+O, and leaves the diffs of `edit` and `write` in place
- [diff-highlight.ts](diff-highlight.ts) paints the code of a diff from `edit` with the theme tokens that pi already applies to a file read and a code block
