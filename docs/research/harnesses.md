# Shipinetics on each harness: comparison

Checked: 2026-11-22. This table merges [harness-contract.md](harness-contract.md) (what Shipinetics needs) with the research notes [harness-codex.md](harness-codex.md), [harness-opencode.md](harness-opencode.md) and [harness-copilot.md](harness-copilot.md). Each cell comes from those notes, which cite the sources. "Copilot" means the Copilot CLI unless a cell says otherwise.

## What each harness gives Shipinetics

| Need | Claude Code | Antigravity | Codex | OpenCode 2 | Copilot |
|---|---|---|---|---|---|
| `AGENTS.md` loads each session | Yes, through `@AGENTS.md` in `CLAUDE.md` | Yes | Yes. Project files together are capped at 32 KiB | Yes. `CLAUDE.md` where no `AGENTS.md` exists | Yes, with `copilot-instructions.md` and `CLAUDE.md` |
| Skills (`SKILL.md`) | Yes, as `shipinetics:<name>` | Yes, as generated copies (`shipinetics install antigravity`, from 0.12.0) | Yes, from the plugin, prefix kept | Yes, from `.claude/skills` and `.agents/skills`. Prefix lost | Yes, from `.github/skills`, `.agents/skills`, `.claude/skills` and plugins |
| `${CLAUDE_PLUGIN_ROOT}` in skill text | Replaced | Not replaced; the generated copies hold real paths (from 0.12.0) | Not replaced. Set for hook commands only | Not replaced | Set for hooks. In skill text: unverified |
| Subagents with their own model | Yes (`model`, `effort`, `tools`) | Yes, but our installer drops `model` and `effort` | Yes: TOML in `~/.codex/agents/`, `model` and `model_reasoning_effort`. No tool allowlist. A plugin can't ship them | Yes: Markdown agents, `model: provider/model#variant`, permissions per agent. A plugin can't add them | Yes: `*.agent.md` with `model`, `tools` and (CLI) `reasoningEffort` |
| Hook before a shell command that can deny | Yes | Yes | Yes, the same format as Claude Code. `ask` counts as a failed hook, so reply `deny` | Yes, through a TypeScript plugin: a throw rejects the call | Yes (CLI, and VS Code in preview): top-level `permissionDecision: "deny"` or exit code 2. A hook that times out lets the action run |
| Hook before a file edit that can deny | Yes (`file_path`) | Yes | Yes, but the path is inside the `apply_patch` text | Yes (`path`), and the multi-file `patch` tool needs parsing | Yes. The path key of the edit tool isn't documented, and `toolArgs` may be a JSON string |
| The hook knows the subagent | `agent_type` | `agentType` | `agent_type` | Agent ID | `agentType`. The value for a plugin agent is unverified |
| Hook after a command that adds context | Yes | Not wired | Yes | Yes: `execute.after` can replace the result | Yes |
| Session start and end hooks | Yes | Yes (Stop) | Yes. `SessionEnd` gets at most 3 seconds | Events: `session.created`, `session.idle`, `session.usage.updated` | Yes |
| Install from a local clone | `claude plugin marketplace add <clone>` (`shipinetics install claude`) | `shipinetics install antigravity` | `codex plugin marketplace add <clone>`, then `codex plugin add`. Installs a copy, so edits need a refresh. You approve each hook once in `/hooks` | A plugin folder in `~/.config/opencode/plugins/`, or a path in `plugins` | `copilot plugin install <clone>`. Our repo has two `hooks.json` files, and which one Copilot reads is unverified |
| Transcripts with token counts | JSONL | JSONL | JSONL rollouts. Not a stable format | SQLite, with tokens and cost per message | `events.jsonl`, with a format that isn't documented |
| Sandbox | Optional (Seatbelt on macOS) | None known | On by default: no network, no local ports, `.git` is read-only | None | Optional (`--sandbox`) |

## What this means for each guard

| Guard | Claude Code | Antigravity | Codex | OpenCode 2 | Copilot CLI |
|---|---|---|---|---|---|
| Secrets guard | Enforced | Enforced | Enforced | Enforced through the plugin | Enforced, but fails open on timeout |
| PR gate | Enforced | Enforced | Enforced. The sandbox blocks `gh` without network | Enforced through the plugin | Enforced, but fails open on a timeout (the gate can take up to 60 seconds) |
| Install gate | Enforced (`ask`) | Enforced | Enforced as `deny`, not `ask` | Enforced through the permission hook | Enforced, but fails open on timeout |
| Edit guard (test-writer only, protected files) | Enforced | Enforced | Enforced, after parsing `apply_patch` | Enforced, after parsing `patch` | Enforced if `agentType` matches; unverified |
| Quick verify after a commit | Yes | No | Yes | Yes | Yes |
| Docs before `/compact` | Yes | No known hook | A PreCompact hook exists; whether it can stop compaction is unverified | Unverified | `preCompact` exists, but it can't stop a compaction and runs only for automatic ones |
| Git hooks and CI | The same everywhere | | | | |

The Copilot cloud agent (the one that opens PRs on GitHub) runs only `.github/hooks/*.json` from the default branch, and it can't push or open PRs itself. There, the PR gate becomes CI required checks and rulesets.

## Open questions that need a real install to answer

1. Codex: do hooks run inside the sandbox, so that the PR gate can reach GitHub? Can an installer pre-approve hooks?
2. OpenCode: can a plugin start a child process (our bash scripts)? Do hooks run for subagent tool calls?
3. Copilot: which `hooks.json` does it read from our plugin? Is `toolArgs` a string? What `agentType` does a plugin agent report? Does it accept Claude's nested reply?
