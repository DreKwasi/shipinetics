# OpenAI Codex as a harness for Shipinetics

Checked: 2026-11-22

Sources: the official Codex docs, which now live at `learn.chatgpt.com/docs` (`developers.openai.com/codex/*` returns a 308 redirect there; for example `https://developers.openai.com/codex/hooks` goes to `https://learn.chatgpt.com/docs/hooks`). I read the Markdown version of each page (add `.md` to the URL). Plugin packaging lives at `developers.openai.com/plugins`. For source code I read the repository `openai/codex` at commit `ba1c17f9600a44d7dadb0b867690a9d936150e8d` (branch `main`, 2026-11-22). In source links below, `SRC` stands for `https://github.com/openai/codex/blob/ba1c17f9600a44d7dadb0b867690a9d936150e8d`. The latest stable release is `rust-v0.171.0` (2026-11-20, https://github.com/openai/codex/releases). Where `main` and the docs differ, I checked the release tag too and say so. I checked every claim on 2026-11-22.

## Summary

Shipinetics can port to Codex with most of its enforcement intact, because Codex copied the Claude Code hook protocol on purpose. Codex reads a Claude-style plugin: it finds `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, loads `skills/` and `hooks/hooks.json` from the plugin root, and sets `CLAUDE_PLUGIN_ROOT` for hook commands. Hook input uses the same snake_case fields (`tool_name`, `tool_input.command`, `cwd`, `session_id`, `agent_type`), and a `PreToolUse` hook denies with the same `hookSpecificOutput.permissionDecision: "deny"` reply. So the secrets guard, the PR gate and the install gate stay enforced for shell commands, and the edit guard stays enforced too, because `PreToolUse` input carries `agent_type` (the custom agent's name) inside a subagent. Four changes are needed: the edit guard must read file paths out of the `apply_patch` text (there is no `file_path` field), the install gate must reply `deny` instead of `ask` (Codex treats `ask` as a failed hook and lets the command run), `SessionEnd` hooks are capped at 3 seconds, and the user must review and trust each hook in `/hooks` before it runs at all. The quick verify after a commit, the companions notice and the usage log map to `PostToolUse`, `SessionStart` and `SessionEnd`, and the transcripts are JSONL with token counts. These parts become instructions only, or need extra work: the per-agent tool lists (a custom agent can't get a read-only tool list; it can only turn off the shell or other features, though a `PreToolUse` hook can deny edits by agent type), the Claude Code deny rules (they become Codex `.rules` files), and custom agents, which a plugin can't ship, so an installer must write them as TOML into `~/.codex/agents/`. The default sandbox also blocks writes to `.git` and all network and local ports, so `git commit`, `gh pr create` and the live app runs need approval or a broader permission profile.

## Table

| Row | Supported? (yes, partly, no, unverified) | How | Source (URL) |
|---|---|---|---|
| 1. Instruction files | yes | `~/.codex/AGENTS.override.md` or `~/.codex/AGENTS.md` (global), then one file per folder from the project root down to the working folder (`AGENTS.override.md`, `AGENTS.md`, then `project_doc_fallback_filenames`). Joined root first. Combined project files are capped by `project_doc_max_bytes` (32 KiB default). Untrusted projects skip project files | https://learn.chatgpt.com/docs/agent-configuration/agents-md , SRC/codex-rs/core/src/agents_md.rs |
| 2. Skills | yes | `SKILL.md` folders with `name` and `description` (plus optional `metadata.short-description`). Read from `.agents/skills` in each folder from the working folder up to the repo root, `~/.agents/skills`, `$CODEX_HOME/skills` (deprecated), the project `.codex/skills`, `/etc/codex/skills`, built-in skills and enabled plugins. Invoked by the model on its own (implicit) or by `$name` or `/skills` (explicit). Plugin skills are named `plugin:skill` | https://learn.chatgpt.com/docs/build-skills , SRC/codex-rs/ext/skills/src/host_roots.rs , SRC/codex-rs/skills/src/parser.rs |
| 3. Custom slash commands | partly | Custom prompts in `~/.codex/prompts/*.md` (frontmatter `description`, `argument-hint`; `$1`..`$9`, `$ARGUMENTS`, named `$KEY`) run as `/prompts:<name>`, but they are deprecated in favor of skills. A plugin's Claude-style `commands/` folder is converted into skills at install | https://learn.chatgpt.com/docs/custom-prompts , SRC/codex-rs/core-plugins/src/command_migration/plugin.rs |
| 4. Subagents | partly | Custom agents are TOML files in `~/.codex/agents/` or `.codex/agents/` with `name`, `description`, `developer_instructions`, and optional `model`, `model_reasoning_effort`. No tool allowlist: an agent can only turn off `features.shell_tool`, `apps`, `plugins`, `memories`, `request_permissions_tool` and skills. The main agent calls the `spawn_agent` tool with `agent_type`. Fresh context by default (`fork_context` omitted). Sandbox and approvals always come from the parent. Plugins can't ship agents | https://learn.chatgpt.com/docs/agent-configuration/subagents , SRC/codex-rs/core/src/tools/handlers/multi_agents_spec.rs , SRC/codex-rs/agent-roles/src/agent_role_config.rs |
| 5. Hooks | yes | `hooks.json` (same shape as Claude Code) in `/etc/codex/`, `$CODEX_HOME/`, trusted `.codex/`, or a plugin's `hooks/hooks.json`; or `[hooks]` in `config.toml`. Events: `SessionStart`, `SessionEnd`, `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PreCompact`, `PostCompact`, `UserPromptSubmit`, `SubagentStart`, `SubagentStop`, `Stop`, `Interrupt`, `PreModelRequest`, `PostModelRequest`. `PreToolUse` denies with `permissionDecision: "deny"`, `{"decision":"block"}` or exit 2; `ask` is not supported. `PostToolUse` adds `additionalContext`. Default timeout 600 s; `SessionEnd` and `Interrupt` 1 s, max 3 s. Each hook needs user trust in `/hooks` | https://learn.chatgpt.com/docs/hooks , SRC/codex-rs/hooks/schema/generated/ |
| 6. Plugins | yes | Portable `plugin.json` with the Agent Plugins `$schema`, or `.codex-plugin/plugin.json`, `.claude-plugin/plugin.json` or `.cursor-plugin/plugin.json`. Marketplaces: `.agents/plugins/marketplace.json` or `.claude-plugin/marketplace.json`. Local install: `codex plugin marketplace add <local folder>`, then `codex plugin add <plugin>@<marketplace>`. Installs a copy under `~/.codex/plugins/cache/`. A public directory exists, but plugins with hooks can't be listed there | https://developers.openai.com/plugins/build/plugins , SRC/codex-rs/utils/plugins/src/plugin_namespace.rs , SRC/codex-rs/core-plugins/src/marketplace.rs , SRC/codex-rs/cli/src/plugin_cmd.rs |
| 7. MCP | yes | Client for stdio (`command`, `args`, `env`) and streamable HTTP (`url`, bearer token, headers, OAuth) servers in `[mcp_servers.<name>]` of `~/.codex/config.toml` or a trusted `.codex/config.toml`. `codex mcp add`, `codex mcp login`, `/mcp`. Plugins can bundle `mcp.json` or `.mcp.json` | https://learn.chatgpt.com/docs/extend/mcp |
| 8. Model selection | yes | `model` and `model_reasoning_effort` in `config.toml`; `--model`/`-m`; `/model`; profiles in `~/.codex/<name>.config.toml` with `--profile`; per subagent in the agent TOML or `[agents] default_subagent_model`. `codex debug models` prints the catalog. Current models: `gpt-6.2-astra`, `gpt-6.2-sol`, `gpt-6.1-sol`, `gpt-6.1-terra`, `gpt-6-astra`, `gpt-6-luna`. Efforts: `low`, `medium`, `high`, `xhigh`, `max`, `ultra`, by model | https://learn.chatgpt.com/docs/models , https://learn.chatgpt.com/docs/config-file/config-advanced , https://learn.chatgpt.com/docs/developer-commands |
| 9. Plans and usage | yes | Plus ($20) and up include Codex in the CLI, IDE, web and iOS. Free and Go get GPT-6 Luna in the desktop app, subject to rollout. Pro is $100, $200 or $500. Business $20 per user per month (annual). Usage is an allowance per five-hour window for Plus and Standard Business (Pro has no five-hour limit now); weekly limits may apply; credits extend it. API-key use pays API prices and has no cloud features | https://learn.chatgpt.com/docs/pricing |
| 10. Transcripts | yes | JSONL rollouts at `$CODEX_HOME/sessions/YYYY/MM/DD/rollout-<timestamp>-<thread id>.jsonl`. Lines are `{"timestamp", "type", "payload"}`. Token counts are in `event_msg` lines of type `token_count` (`info.total_token_usage`, `info.last_token_usage`) and in `token_usage_record` lines. Each subagent has its own rollout file. Hooks get the path as `transcript_path`, but the format is not a stable interface | https://learn.chatgpt.com/docs/hooks , SRC/codex-rs/rollout/src/recorder.rs , SRC/codex-rs/history/src/rollout_payload.rs , SRC/codex-rs/protocol/src/protocol.rs |
| 11. Sandbox and approvals | yes | `sandbox_mode` (`read-only`, `workspace-write`, `danger-full-access`) plus `approval_policy` (`on-request`, `never`, granular). Default `workspace-write`: writes only in the workspace and temp folders; `.git`, `.agents`, `.codex`, `.aws` stay read-only; no network; no local ports (`allow_local_binding = false`). `.rules` files (Starlark `prefix_rule`) allow, prompt or forbid command prefixes | https://learn.chatgpt.com/docs/sandboxing , https://learn.chatgpt.com/docs/agent-approvals-security , https://learn.chatgpt.com/docs/agent-configuration/rules |
| 12. Headless and git/PR | yes | `codex exec` (read-only sandbox by default, `--json` JSONL events, `--output-schema`, `-o`, `resume`), `codex review` (`--uncommitted`, `--base`, `--commit`), the `openai/codex-action` GitHub Action, and cloud reviews on GitHub PRs (`@codex review`, automatic reviews, `## Code Review Rules` in `AGENTS.md`). Codex has no PR gate of its own; Shipinetics' gate stays a `PreToolUse` hook on `gh pr create` | https://learn.chatgpt.com/docs/non-interactive-mode , https://learn.chatgpt.com/docs/developer-commands , https://learn.chatgpt.com/docs/github-action , https://learn.chatgpt.com/docs/code-review |

## 1. Instruction files

Source: https://learn.chatgpt.com/docs/agent-configuration/agents-md (checked 2026-11-22).

- Global: Codex reads `~/.codex/AGENTS.override.md` if it exists, else `~/.codex/AGENTS.md`. `CODEX_HOME` moves `~/.codex`. "Codex uses only the first non-empty file at this level."
- Project: "Starting at the project root (typically the Git root), Codex walks down to your current working directory." In each folder it takes the first of `AGENTS.override.md`, `AGENTS.md`, then the names in `project_doc_fallback_filenames`. "Codex includes at most one file per directory."
- Merge: "Codex concatenates files from the root down, joining them with blank lines. Files closer to your current directory override earlier guidance because they appear later in the combined prompt."
- Size: "Codex skips empty files and stops adding files once the combined size reaches the limit defined by `project_doc_max_bytes` (32 KiB by default)." The config page (https://learn.chatgpt.com/docs/config-file/config-advanced#project-instructions-discovery) says "how much to read from each `AGENTS.md` file", which conflicts. The source settles it: one budget for all project files, and the file that crosses it is cut (SRC/codex-rs/core/src/agents_md.rs, `remaining` budget and `data.truncate(remaining)`). The global file doesn't count against it ("The limit applies only to project files", SRC/codex-rs/core/src/agents_md_manager.rs).
- Trust: the source returns no project docs when the project is untrusted (`if config.active_project.is_untrusted() || config.project_doc_max_bytes == 0`, SRC/codex-rs/core/src/agents_md.rs line 65).
- Other files: no `CLAUDE.md` support by default. Add it with the fallback list:

```toml
# ~/.codex/config.toml
project_doc_fallback_filenames = ["TEAM_GUIDE.md", ".agents.md"]
project_doc_max_bytes = 65536
```

- Codex rebuilds the chain at each run or TUI session start. `/init` writes an `AGENTS.md` scaffold. GitHub code review reads a `## Code Review Rules` section from the nearest `AGENTS.md`.
- Shipinetics impact: our setup already writes an `AGENTS.md` block. It loads as is. A `CLAUDE.md` that only imports `AGENTS.md` is not needed for Codex.

## 2. Skills

Sources: https://learn.chatgpt.com/docs/build-skills (2026-11-22), SRC/codex-rs/ext/skills/src/host_roots.rs, SRC/codex-rs/skills/src/parser.rs.

- Format: a folder with `SKILL.md` and optional `scripts/`, `references/`, `assets/`, `agents/openai.yaml`. "The `SKILL.md` file must include `name` and `description`."

```md
---
name: skill-name
description: Explain exactly when this skill should and should not trigger.
---

Skill instructions for ChatGPT or Codex to follow.
```

- Frontmatter the parser reads: `name` (defaults to the folder name, max length enforced), `description` (required), `metadata.short-description`. Other keys are ignored. The parser repairs common YAML mistakes such as `description: Build for AWS: ECS`. Source: `SkillFrontmatter` in SRC/codex-rs/skills/src/parser.rs.
- Extra settings in `agents/openai.yaml`: `interface` (display name, icons, `default_prompt`), `policy.allow_implicit_invocation` (default `true`), `dependencies.tools` (for example an MCP server).
- Folders (docs table, confirmed in source):
  - `$CWD/.agents/skills`, each parent's `.agents/skills`, up to `$REPO_ROOT/.agents/skills` (scope `REPO`).
  - `$HOME/.agents/skills` (scope `USER`).
  - `$CODEX_HOME/skills`, that is `~/.codex/skills`. The source calls it "Deprecated user skills location (`$CODEX_HOME/skills`), kept for backward compatibility". The bundled `skill-installer` still installs there (SRC/codex-rs/skills/src/assets/samples/skill-installer/SKILL.md).
  - The project `.codex/skills` (project config layer; source only, not in the docs table).
  - `/etc/codex/skills` (scope `ADMIN`).
  - Bundled system skills (`skill-creator`, `skill-installer`).
  - Skills inside enabled plugins. They get the name `<plugin>:<skill>` (SRC/codex-rs/ext/skills/src/loader/namespace.rs: `format!("{namespace}:{base_name}")`). So `shipinetics:workflow` keeps its name.
  - Symlinked skill folders work.
- Invocation: "Explicit invocation: ... In Codex CLI or the IDE extension, run `/skills` or type `$` to mention a skill." "Implicit invocation: ... Codex can choose a skill when your task matches the skill `description`." The model first sees name, description and file path, within 2% of the context window (or 8,000 characters), set by `skills.max_context_tokens` up to 10,000 tokens.
- Turn off a skill:

```toml
[[skills.config]]
path = "/path/to/skill/SKILL.md"
enabled = false
```

- `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` in skill text are not replaced. A search of the source found these names only in hook discovery (SRC/codex-rs/hooks/src/engine/discovery.rs). The model does get each skill's file path, so paths relative to the skill folder can work.

## 3. Custom slash commands or prompts

Sources: https://learn.chatgpt.com/docs/custom-prompts (2026-11-22), https://learn.chatgpt.com/docs/developer-commands (2026-11-22).

- "Custom prompts are deprecated. Use skills for reusable instructions that Codex can invoke explicitly or implicitly."
- Format and place: top-level Markdown files in `~/.codex/prompts/` (not in the repo, no subfolders). Invoked as `/prompts:<name>` in the CLI and IDE extension.

```markdown
---
description: Prep a branch, commit, and open a draft PR
argument-hint: [FILES=<paths>] [PR_TITLE="<title>"]
---

Create a branch named `dev/<feature_name>` for this work.
If files are specified, stage them first: $FILES.
```

- Placeholders: `$1`..`$9`, `$ARGUMENTS`, uppercase named `$FILE` given as `KEY=value`, `$$` for a literal `$`.
- `/presets` saves a prompt or slash command in a numbered slot (CLI).
- Plugins: on install, Codex turns a non-portable plugin's `commands/` folder into skills named `source-command-<name>` (frontmatter `description` required, 4,000 bytes max each). Source: SRC/codex-rs/core-plugins/src/command_migration/plugin.rs and SRC/codex-rs/core-plugins/src/store.rs line 644.
- `/import` converts Claude Code slash commands into skills (https://learn.chatgpt.com/docs/import).
- Shipinetics impact: our entry points are already skills (`/shipinetics:spec` style). In Codex the user types `$shipinetics:spec` or picks it in `/skills`.

## 4. Subagents

Sources: https://learn.chatgpt.com/docs/agent-configuration/subagents (2026-11-22), SRC/codex-rs/core/src/tools/handlers/multi_agents_spec.rs, SRC/codex-rs/agent-roles/src/agent_role_config.rs, SRC/codex-rs/features/src/lib.rs.

- Built-in agents: `default`, `worker`, `explorer`.
- Custom agents: "add standalone TOML files under `~/.codex/agents/` for personal agents or `.codex/agents/` for project-scoped agents." Required: `name`, `description`, `developer_instructions`. Optional: `model`, `model_reasoning_effort`, `model_reasoning_summary`, `model_verbosity`, `nickname_candidates`, and other config keys.

```toml
name = "reviewer"
description = "PR reviewer focused on correctness, security, and missing tests."
model = "gpt-6.2-sol"
model_reasoning_effort = "medium"
developer_instructions = """
Review code like an owner.
Do not edit files.
"""
```

- Own model and effort: yes. "If a custom agent file sets `model` or `model_reasoning_effort`, the value in the file takes precedence." Otherwise the spawn call, then `[agents] default_subagent_model` / `default_subagent_reasoning_effort`, then the parent.
- Tools: no per-tool allowlist. "To reduce a custom agent's capabilities, set supported feature keys to `false`: `features.shell_tool`, `features.apps`, `features.plugins`, `features.memories`, or `features.request_permissions_tool`." Skills can be turned off with `skills.config`. There is no key to remove `apply_patch` (file edits).
- Permissions: "Subagents inherit the parent turn's current sandbox and approval settings ... A custom agent file can't replace those settings." "Custom agent instructions can ask an agent to avoid edits, but they don't create a separate read-only sandbox." MCP servers also come from the parent.
- How the main agent calls them: the `spawn_agent` tool with `message`, `agent_type`, `fork_context`, `model`, `reasoning_effort`; then `wait_agent`, `send_input`, `close_agent`. The tool text says: "Do not spawn sub-agents unless the user or applicable AGENTS.md/skill instructions explicitly ask for sub-agents, delegation, or parallel agent work." So a skill that says "spawn the test-writer agent" counts as permission.
- Fresh context: yes by default. `fork_context`: "True forks the current thread history into the new agent; false or omitted starts with only the initial prompt." (multi-agent v1, the default; `multi_agent_v2` is `default_enabled: false`). In v2, `fork_turns` defaults to `all`, so a v2 user would get the parent history unless the call passes `none`.
- Plugins can't ship agents: the plugin manifest has no `agents` field (`RawPluginManifest` in SRC/codex-rs/core-plugins/src/manifest.rs lists `skills`, `mcp_servers`, `apps`, `hooks`, `interface`, `extensions`). An installer must write `~/.codex/agents/*.toml`, like `bin/shipinetics-antigravity` does for Antigravity.
- `/import` from Claude Code converts subagents, but it drops `tools` and `model`. It keeps `name`, `description`, the body as `developer_instructions`, `effort` (maps `max` to `xhigh`) and `permissionMode` (`acceptEdits` to `workspace-write`, `readOnly` to `read-only`). Source: SRC/codex-rs/external-agent-migration/src/subagents.rs.
- Surfaces: CLI (`/subagents`), IDE extension and desktop app. In ChatGPT Work on the web, there are subagents but no custom agent files.

## 5. Hooks

Source: https://learn.chatgpt.com/docs/hooks (2026-11-22), the generated schemas at SRC/codex-rs/hooks/schema/generated/, and SRC/codex-rs/hooks/src/. I checked the `agent_type` field in the release tag too (https://raw.githubusercontent.com/openai/codex/rust-v0.171.0/codex-rs/hooks/src/events/pre_tool_use.rs, also present in `rust-v0.168.0`).

### Events

| When | Hooks |
|---|---|
| During a turn | `PreToolUse`, `PermissionRequest`, `PostToolUse`, `PreCompact`, `PostCompact`, `UserPromptSubmit`, `SubagentStop`, `Stop` |
| For each model request attempt | `PreModelRequest`, `PostModelRequest` |
| When you interrupt an active turn | `Interrupt` (doesn't run for subagents) |
| When a session or subagent starts | `SessionStart`, `SubagentStart` |
| When the main thread ends | `SessionEnd` (doesn't run for subagents) |

`SessionStart` matcher values: `startup`, `resume`, `clear`, `compact`, `fork`. `SessionEnd` runs when a conversation closes, is archived or deleted, or after 30 minutes idle; `reason` is always `other`.

### Location and format

- `/etc/codex/hooks.json`, `$CODEX_HOME/hooks.json` (`~/.codex/hooks.json`), trusted project `.codex/hooks.json`, or inline `[hooks]` in `config.toml` at each layer. Enabled plugins add `hooks/hooks.json` from the plugin root, or the `hooks` entry of the manifest.
- Same three levels as Claude Code: event, matcher group, handlers. `type` is `command` or `mcp_tool` (`prompt` and `agent` are "parsed but skipped"). Fields: `command`, `timeout` (seconds), `statusMessage`, `async`, `additionalContextLimit`, `commandWindows`.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "/usr/bin/python3 \"$(git rev-parse --show-toplevel)/.codex/hooks/pre_tool_use_policy.py\"",
            "statusMessage": "Checking Bash command"
          }
        ]
      }
    ]
  }
}
```

- Commands run through `$SHELL -lc` (fallback `/bin/sh`), so `"${CLAUDE_PLUGIN_ROOT}"/scripts/x.sh` expands (SRC/codex-rs/hooks/src/engine/command_runner.rs). "Commands run with the session `cwd` as their working directory." The source spawns hooks as plain processes; the docs don't say whether the tool sandbox applies to them (see Open questions).
- Plugin hooks get `PLUGIN_ROOT`, `PLUGIN_DATA`, and "Codex also sets `CLAUDE_PLUGIN_ROOT` and `CLAUDE_PLUGIN_DATA` for compatibility with existing plugin hooks."
- Matching hooks from all sources run, and they run at the same time ("launched concurrently").
- Trust: "Before a non-managed hook can run, Codex requires you to review and trust the exact hook definition. Codex records trust against the hook's current hash, so new or changed hooks are marked for review and skipped until trusted." Use `/hooks` in the CLI, or Settings > Hooks in the desktop app. "If a plugin update changes a bundled script, Codex requires a new review even if the hook definition stays the same." `--dangerously-bypass-hook-trust` skips trust for one run.
- Hooks are on by default (`[features] hooks = true`).

### Matchers and tool names

- `matcher` is a regex on the tool name. Shell commands and `exec_command` match as `Bash`. File edits use `apply_patch` and also match `Edit` or `Write`, but input still says `tool_name: "apply_patch"`. MCP tools match as `mcp__server__tool`. `spawn_agent` also matches `Agent`. Hosted tools such as `WebSearch` don't run hooks.
- The tool coverage table names no file-read tool. Codex reads files with shell commands.
- "Some specialized tool paths can opt out of the default hook path. Treat tool hooks as a useful guardrail, not a complete enforcement boundary."

### Input payload

Common fields: `session_id` ("Subagent hook uses the parent session id"), `transcript_path` (string or null), `cwd`, `hook_event_name`, `model`. Turn events add `turn_id`. Most events add `permission_mode` (`default`, `acceptEdits`, `plan`, `dontAsk`, `bypassPermissions`).

`PreToolUse` input from the generated schema (`pre-tool-use.command.input.schema.json`):

| Field | Required | Meaning |
|---|---|---|
| `session_id` | yes | Session id |
| `turn_id` | yes | Codex extension |
| `transcript_path` | yes (string or null) | Rollout path |
| `cwd` | yes | Working folder. For local commands this is the command's own cwd |
| `hook_event_name` | yes | `"PreToolUse"` |
| `model` | yes | Model slug |
| `permission_mode` | yes | See above |
| `tool_name` | yes | `Bash`, `apply_patch`, `mcp__fs__read`, ... |
| `tool_use_id` | yes | Call id |
| `tool_input` | yes | `Bash` and `apply_patch`: `{"command": "..."}`. MCP and other tools: their arguments |
| `agent_id` | no | Present only inside a spawned subagent |
| `agent_type` | no | Present only inside a spawned subagent: the custom agent `name`, or `default` |

The `agent_type` value comes from the spawned agent's role: `agent_role.clone().unwrap_or_else(|| DEFAULT_ROLE_NAME)` (SRC/codex-rs/core/src/hook_runtime.rs line 1103). The docs table for `PreToolUse` doesn't list `agent_id` and `agent_type`; the schema and the released source do. `PostToolUse` has the same fields plus `tool_response`.

For `apply_patch`, `tool_input.command` holds the patch text, not a path. File paths follow these markers (SRC/codex-rs/apply-patch/src): `*** Begin Patch`, `*** Add File: `, `*** Delete File: `, `*** Update File: `, `*** Move to: `, `*** End Patch`.

`SessionEnd` example from the docs:

```json
{
  "session_id": "thr_123",
  "transcript_path": "/workspace/.codex/rollout.jsonl",
  "cwd": "/workspace",
  "hook_event_name": "SessionEnd",
  "reason": "other"
}
```

### Replies

`PreToolUse` deny:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Destructive command blocked by hook."
  }
}
```

Also accepted: `{"decision": "block", "reason": "..."}`, or exit code `2` with the reason on stderr. Plain text on stdout is ignored. `additionalContext` adds model-visible text without blocking. `permissionDecision: "allow"` with `updatedInput` rewrites the call.

Not supported: "`permissionDecision: "ask"`, legacy `decision: "approve"`, `continue: false`, `stopReason`, and `suppressOutput` are parsed but not supported yet. Codex marks the hook run as failed, reports the error, and continues the tool call." Empty output with exit 0 is success. For cloud-orchestrated hooks the docs add: "A `PreToolUse` error, timeout, or malformed response can let the tool run."

`PermissionRequest` runs only when Codex is about to ask for approval. It can allow or deny:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PermissionRequest",
    "decision": { "behavior": "deny", "message": "Blocked by repository policy." }
  }
}
```

`PostToolUse` adds context, and can replace the result with feedback:

```json
{
  "decision": "block",
  "reason": "The Bash output needs review before continuing.",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "The command updated generated files."
  }
}
```

"That `additionalContext` text is added as extra developer context." `PostToolUse` also runs after a Bash command that exits non-zero.

`SessionStart`: plain text on stdout or `hookSpecificOutput.additionalContext` becomes developer context; `systemMessage` shows a warning to the user.

`Stop` and `SubagentStop`: `{"decision": "block", "reason": "..."}` makes Codex continue with the reason as a new prompt.

### Timeouts and limits

- "If `timeout` is omitted, Codex uses `600` seconds for most hooks." "`SessionEnd` and `Interrupt` use `1` second by default and support up to `3` seconds."
- Model-visible hook output is cut at about 2,500 tokens by default; the rest is saved under `<temp_dir>/hook_outputs/<session_id>/`.
- `async: true` runs a hook in the background (max eight at a time); background hooks can't block.

### Shipinetics mapping

| Shipinetics hook | Codex | Change needed |
|---|---|---|
| `guard-edits.sh` on `Edit\|Write\|NotebookEdit` | `PreToolUse`, matcher `Edit\|Write` (matches `apply_patch`) | Parse paths from `tool_input.command` patch text. `agent_type` works for the test-writer rule |
| `guard-secrets.sh` on `Bash\|Read` | `PreToolUse`, `Bash` | None for Bash. There is no Read tool |
| `guard-pr.sh` on `Bash` | `PreToolUse`, `Bash` | None. `cwd` is present |
| `guard-installs.sh` on `Bash` (uses `ask`) | `PreToolUse`, `Bash` | Reply `deny` with a reason, or move the ask to a `.rules` `prompt` rule. `ask` fails open |
| `verify-after-commit.sh` | `PostToolUse`, `Bash`, `additionalContext` | None, but `git commit` needs `.git` write access first (row 11) |
| `companions-notice.sh` | `SessionStart`, matcher `startup` | None |
| `usage-record.sh` (timeout 5) | `SessionEnd` | Timeout max 3 s |

`sy_hook_harness` in `scripts/lib.sh` returns `claude` under Codex, because Codex sets both `PLUGIN_ROOT` and `CLAUDE_PLUGIN_ROOT` and sends no Antigravity keys. Codex-only fields such as `turn_id` can tell the two apart if needed.

## 6. Plugins or extensions

Sources: https://developers.openai.com/plugins/build/plugins (2026-11-22), https://learn.chatgpt.com/docs/plugins (2026-11-22), SRC/codex-rs/utils/plugins/src/plugin_namespace.rs, SRC/codex-rs/exec-server-protocol/src/protocol.rs, SRC/codex-rs/core-plugins/src/marketplace.rs, SRC/codex-rs/core-plugins/src/loader.rs, SRC/codex-rs/cli/src/plugin_cmd.rs.

- Manifest: the portable form is root `plugin.json` with `"$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"`, plus `skills/` and `mcp.json`. OpenAI settings (hooks, apps, interface) go in `extensions.com.openai`. "OpenAI also accepts legacy and Claude-compatible manifests."
- Manifest lookup order in source: root `plugin.json` only if its `$schema` is an Agent Plugins URL; otherwise `.codex-plugin/plugin.json`, `.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`. Shipinetics' root `plugin.json` has no `$schema`, so Codex skips it and reads `.claude-plugin/plugin.json`.
- Default component paths for legacy manifests: `skills`, `hooks/hooks.json`, `.mcp.json`, `.app.json` (SRC/codex-rs/core-plugins/src/loader.rs).
- Marketplace files Codex reads: `.agents/plugins/marketplace.json`, `.agents/plugins/api_marketplace.json`, `.claude-plugin/marketplace.json`, `.cursor-plugin/marketplace.json`. A local `source` of `"./"` means the marketplace root, and `policy` has a default, so our `.claude-plugin/marketplace.json` entry (`"source": "./"`) parses.
- Install from a local folder (CLI):

```bash
codex plugin marketplace add ./local-marketplace-root
codex plugin add sample@debug
```

`codex plugin add` takes `PLUGIN@MARKETPLACE`; `codex plugin list` and `codex plugin remove` also exist. The docs add: "These commands support plugin authoring and catalog setup. Use the ChatGPT desktop app to install and test a local plugin."
- Install location: "`~/.codex/plugins/cache/$MARKETPLACE_NAME/$PLUGIN_NAME/$VERSION/`. For local plugins, `$VERSION` is `local`, and ChatGPT loads the installed copy from that cache path." So edits in the clone need a refresh, unlike the symlinks of `shipinetics-antigravity`.
- Enable per project: `[plugins."my-plugin@local-repo"] enabled = true` in `.codex/config.toml`.
- Hooks in plugins: "Lifecycle hooks are supported for plugins installed manually in Codex desktop. Plugins containing lifecycle hooks aren't eligible for the public plugin directory." The hooks page says enabled plugins supply hooks in local Codex generally. "Installing or enabling a plugin doesn't automatically trust its hooks."
- Marketplace: one public "universal plugin directory shared by ChatGPT and Codex" (submission portal). Git, local and npm sources work for private marketplaces.
- `/import` from Claude Code can import plugins (https://learn.chatgpt.com/docs/import).

## 7. MCP

Source: https://learn.chatgpt.com/docs/extend/mcp (2026-11-22).

- Client: yes. Transports: STDIO and streamable HTTP.
- Config in `~/.codex/config.toml` or a trusted project `.codex/config.toml`:

```toml
[mcp_servers.context7]
command = "npx"
args = ["-y", "@upstash/context7-mcp"]
env_vars = ["LOCAL_TOKEN"]

[mcp_servers.figma]
url = "https://mcp.figma.com/mcp"
bearer_token_env_var = "FIGMA_OAUTH_TOKEN"
```

- Options: `startup_timeout_sec` (default 10), `tool_timeout_sec` (default 60), `enabled_tools`, `disabled_tools`, `required`, OAuth settings.
- CLI: `codex mcp add <name> -- <command>`, `codex mcp add <name> --url <url>`, `codex mcp login <name>`. TUI: `/mcp`.
- Hooks can call MCP tools (`type: "mcp_tool"`).

## 8. Model selection

Sources: https://learn.chatgpt.com/docs/models, https://learn.chatgpt.com/docs/model-selection, https://learn.chatgpt.com/docs/config-file/config-advanced#profiles, https://learn.chatgpt.com/docs/config-file/config-reference, https://learn.chatgpt.com/docs/developer-commands (all 2026-11-22).

- Global: `model = "gpt-6.2-sol"` and `model_reasoning_effort` in `~/.codex/config.toml`. `[models.new_thread]` sets defaults for new threads. CLI: `codex --model gpt-6.2-sol`, `codex exec -m ...`. TUI: `/model` (and "More reasoning…" for Max or Ultra).
- Profiles: since 0.134.0, a profile is a separate file `~/.codex/<name>.config.toml`, used with `--profile <name>`. `[profiles.x]` tables in `config.toml` are no longer read.
- Per subagent: `model` and `model_reasoning_effort` in the agent TOML, or `[agents] default_subagent_model` and `default_subagent_reasoning_effort`, or the `spawn_agent` call.
- List models: `codex debug models` "Print the raw model catalog Codex sees as JSON." (`--bundled` for the catalog in the binary).
- Models named in the docs today: `gpt-6.2-astra` (default context 272,000 tokens in Codex), `gpt-6.2-sol` (500,000), `gpt-6.1-sol`, `gpt-6.1-terra` (CLI 0.159.0 or later), `gpt-6-astra`, `gpt-6-luna`. Astra and Sol 6.2 support up to 1 million tokens with `model_context_window`. Retired with ChatGPT sign-in: `gpt-5.5` (2026-10-14), `gpt-5.4`, `gpt-5.4-mini` (2026-08-31), `gpt-5.3-codex-spark` (2026-09-14); `gpt-5.2` and `gpt-5.3-codex` are deprecated. API-key sessions follow the API catalog.
- Efforts: `model_reasoning_effort` is "Reasoning effort advertised by the selected model, such as `low`, `medium`, `high`, `xhigh`, `max`, or `ultra`. Available levels depend on the model and client." The schema type is any non-empty string. GPT-6 Luna supports up to Max, not Ultra. Ultra uses subagents.
- Suggested mapping for our agents (my reading of the docs' guidance, not an OpenAI mapping): Claude `opus` to `gpt-6.2-astra` or `gpt-6.2-sol`, `sonnet` to `gpt-6.2-sol` or `gpt-6-luna`. Claude `effort` values `medium` and `high` exist in Codex as is.

## 9. Plans and usage

Source: https://learn.chatgpt.com/docs/pricing (2026-11-22). The docs also point to the Help Center article https://help.openai.com/en/articles/20001275-chatgpt-work-and-codex, which I didn't read.

- "ChatGPT Work and Codex share pricing, credits, and usage limits."
- Free ($0) and Go ($8 per month): "GPT-6 Luna at Standard speed in the desktop app, subject to rollout."
- Plus ($20 per month): "Codex on the web, in the CLI, in the IDE extension, and on iOS", cloud integrations (automatic code review, Slack), GPT-6.1 Sol and GPT-6 Luna, extend usage with credits.
- Pro: "Plans at $100, $200, or $500 USD per month". Ultrafast mode on Pro $500.
- Business: $20 per user per month billed annually (2+ users), $25 billed monthly.
- Enterprise and Edu: contact sales. GPT-6.2 models are off by default until an admin turns them on.
- GPT-6.2 Astra and GPT-6.2 Sol are available on Plus, Pro, Business, Enterprise and Edu, in the Codex app and CLI.
- Limits: "The estimates below show local messages per five-hour period for Plus and Standard Business. Pro plans currently have no five-hour limit." "Local messages and cloud chats share your plan's usage allowance. Weekly limits may also apply." Enterprise and Edu with flexible pricing have no fixed rate limits. Use depends on model, context, reasoning and tools. Fast and Ultrafast modes cost 2x to 8x.
- API key: "Codex in the CLI, SDK, or IDE extension", "No cloud-based features (GitHub code review, Slack, etc.)", "Pay for Codex usage based on API pricing". `CODEX_API_KEY` works with `codex exec`, `codex review` and the SDK.
- `/status` shows token usage and rate limits; `/usage` shows account usage.

## 10. Transcripts

Sources: SRC/codex-rs/rollout/src/recorder.rs (lines 1710-1713), SRC/codex-rs/rollout/src/lib.rs, SRC/codex-rs/rollout/src/rollout_file_name.rs, SRC/codex-rs/history/src/rollout_payload.rs, SRC/codex-rs/rollout/src/policy.rs, SRC/codex-rs/protocol/src/protocol.rs, https://learn.chatgpt.com/docs/hooks, https://learn.chatgpt.com/docs/non-interactive-mode (all 2026-11-22). I checked the token records in the release tag too (https://raw.githubusercontent.com/openai/codex/rust-v0.171.0/codex-rs/rollout/src/policy.rs).

- Location: `$CODEX_HOME/sessions/<year>/<month>/<day>/` and `$CODEX_HOME/archived_sessions/`. File name: `rollout-<YYYY-MM-DDTHH-MM-SS>-<thread id>.jsonl` (reverted threads add `_<rollout id>`). The docs pages don't give this layout; it comes from the source. `codex exec --ephemeral` writes no rollout. `/rollout` in the TUI prints the current path.
- `~/.codex/history.jsonl` is a different file: the prompt history (`[history] persistence = "none"` turns it off).
- Format: JSONL. Each line is `{"timestamp": ..., "ordinal"?: ..., "type": ..., "payload": ...}` with `type` one of `session_meta`, `response_item`, `turn_context`, `token_usage_record`, `event_msg`, `compacted`, `inter_agent_communication`, and others.
- Token usage: yes, in two shapes.
  - `event_msg` with payload type `token_count`: `info.total_token_usage` and `info.last_token_usage`, each with `input_tokens`, `cached_input_tokens`, `cache_write_input_tokens`, `output_tokens`, `reasoning_output_tokens`, `total_tokens`; plus `info.model_context_window` and `rate_limits`.
  - `token_usage_record`: `thread_id`, `turn_id`, `session_id`, `root_turn_id`, `response_id`, `usage`, `turn_token_usage`, `thread_token_usage`.
- Model per turn: `turn_context` lines.
- Subagents: each spawned agent is its own thread with its own rollout file. In `session_meta`, "session_id is equal to the root thread's ID" and `parent_thread_id` links to the parent. `SubagentStop` hooks get `agent_transcript_path`.
- `codex exec --json` prints `turn.completed` events with `usage` (`input_tokens`, `cached_input_tokens`, `output_tokens`, `reasoning_output_tokens`).
- Stability: "`transcript_path` points to a chat transcript for convenience, but the transcript format isn't a stable interface for hooks and may change over time."
- Two features under development can change the files: `local_thread_store_compression` compresses rollouts older than 7 days to `.jsonl.zst`, and `background_paginated_rollout_migration` moves legacy rollouts to paginated history. Both are `default_enabled: false` (SRC/codex-rs/features/src/lib.rs). A `codex migrate-rollouts` command exists.
- `PostModelRequest` hooks get `token_usage` per model request, if a live log is wanted instead of parsing files.

## 11. Sandbox and approvals

Sources: https://learn.chatgpt.com/docs/sandboxing, https://learn.chatgpt.com/docs/agent-approvals-security, https://learn.chatgpt.com/docs/agent-configuration/rules, https://learn.chatgpt.com/docs/permissions (all 2026-11-22), SRC/codex-rs/sandboxing/src/seatbelt.rs, SRC/codex-rs/sandboxing/src/seatbelt_base_policy.sbpl.

- Model: the sandbox sets what commands can touch; the approval policy says when Codex asks. "The sandbox applies to spawned commands, not just to built-in file operations."
- Sandbox modes: `read-only`, `workspace-write` (default for version-controlled folders), `danger-full-access`. Approval policies: `on-request`, `never`, and `granular`; `untrusted` is retired. `approvals_reviewer = "auto_review"` sends eligible prompts to a reviewer agent. Named permission profiles exist (`[permissions.<name>]`).
- Platform: macOS Seatbelt (`sandbox-exec`), Linux and WSL2 bubblewrap, native Windows sandbox.
- What a sandboxed command can't do in `workspace-write`:
  - Write outside the workspace (the current folder plus temp folders like `/tmp`; more with `sandbox_workspace_write.writable_roots`).
  - Write to protected paths: "`<writable_root>/.git` is protected as read-only whether it appears as a directory or file", and also `.agents`, `.codex`, `.aws`, recursively. So `git commit` and `git push` need an approval or a rule.
  - Use the network: "the default `workspace-write` sandbox mode keeps network access turned off unless you enable it" (`sandbox_workspace_write.network_access = true`).
  - Bind or reach local ports: with network on and the proxy on, "`allow_local_binding = false` blocks loopback, link-local, and private destinations". With network off, the macOS profile starts with `(deny default)` and adds no `network-bind` or `network-inbound` rule (SRC/codex-rs/sandboxing/src/seatbelt.rs, `dynamic_network_policy_for_network`), so a dev server can't listen and a test can't reach `localhost`.
- Rules: Starlark files in `rules/` next to a config layer (`~/.codex/rules/default.rules`, trusted `<repo>/.codex/rules/`). They control "which commands Codex can run outside the sandbox".

```python
prefix_rule(
    pattern = ["gh", "pr", "view"],
    decision = "prompt",            # allow | prompt | forbidden
    justification = "Viewing PRs is allowed with approval",
)
```

  The most restrictive match wins (`forbidden` > `prompt` > `allow`). Simple `&&`, `||`, `;`, `|` chains are split; scripts with redirects, `$(...)`, variables or globs are matched as one `bash -lc` string. `codex execpolicy check` tests a rule.
- Subagents inherit the parent's sandbox and approvals.
- Trust: untrusted projects skip project `.codex/` layers: "project-local config, hooks, and rules" (config reference, `projects.<path>.trust_level`).

## 12. Non-interactive mode and git/PR features

Sources: https://learn.chatgpt.com/docs/non-interactive-mode, https://learn.chatgpt.com/docs/developer-commands, https://learn.chatgpt.com/docs/github-action, https://learn.chatgpt.com/docs/code-review, https://learn.chatgpt.com/docs/agent-configuration/agents-md (all 2026-11-22).

- `codex exec "<task>"`: streams progress to stderr, prints the final message to stdout. "By default, `codex exec` runs in a read-only sandbox." Use `--sandbox workspace-write` or `--approve-for-me`. `--full-auto` is gone.
- `--json` gives JSONL events (`thread.started`, `turn.started`, `turn.completed`, `turn.failed`, `item.*`, `error`). `--output-schema` and `-o` give structured final output. `codex exec resume --last` continues a run. `--ephemeral` skips the rollout. Codex needs a git repo unless `--skip-git-repo-check`.
- Trust: "Local `codex exec` and `codex review` runs load project configuration and project-defined MCP servers only for trusted projects". `--trust` saves trust. `--ignore-rules` skips `.rules` files.
- `codex review`: non-interactive review with one of `--uncommitted`, `--base`, `--commit`, or a custom prompt. `/review` in the TUI does the same.
- GitHub: `openai/codex-action` runs Codex in Actions with an API-key proxy. Cloud reviews on GitHub PRs come from the ChatGPT Codex connector: automatic reviews or `@codex review` comments. They read `## Code Review Rules` from `AGENTS.md`. Cloud features need a ChatGPT plan, not an API key.
- PR gate: Codex has no built-in rule that blocks `gh pr create`. Shipinetics keeps its own gate as a `PreToolUse` hook on `Bash`. In the default sandbox, `gh pr create` also needs network access, so it already goes through an approval or a rule.

## Open questions

- Do hooks run inside the tool sandbox? The source spawns them as plain processes (SRC/codex-rs/hooks/src/engine/command_runner.rs), but the docs don't say. `guard-pr.sh` runs `gh` and `shipinetics-verify`, which need network and file access. Unverified.
- Does a `forbidden` `.rules` entry block a command that runs inside the sandbox, or only an escalation? The page says rules control "which commands Codex can run outside the sandbox". This matters for replacing the `.claude/settings.json` deny rules. Unverified.
- Do hooks run in the IDE extension? The hooks page names the CLI (`/hooks`) and the desktop app (Settings > Hooks) only. Unverified.
- Do repo hooks, `.codex/agents/` and skills run in Codex Cloud tasks? The hooks page says cloud orchestration "does not support command ... handlers, hooks from local configuration, plugins, or local directories". Codex Cloud environments were not checked in depth. Unverified.
- Does `codex plugin add` from the CLI enable a plugin's bundled hooks, or only the desktop app? The plugin page says hooks are "supported for plugins installed manually in Codex desktop"; the hooks page says enabled plugins supply hooks. Unverified until tested.
- Where is hook trust stored, and can an installer pre-approve hooks without the user opening `/hooks`? I found only `--dangerously-bypass-hook-trust` and managed hooks in `requirements.toml`. Unverified.
- Does the plugin cache copy keep symlinks, and does `codex plugin marketplace upgrade` refresh a local plugin after the clone changes? Unverified.
- Does `SessionEnd` with `timeout: 5` fail to load or get capped to 3 seconds? The docs say only "support up to `3` seconds". Unverified.
- `project_doc_max_bytes`: the AGENTS.md page and the source say combined; the config page says per file. The source wins, but OpenAI should fix one page.
