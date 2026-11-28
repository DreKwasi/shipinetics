# GitHub Copilot as a harness for Shipinetics

Checked: 2026-11-22

Sources: docs.github.com (raw article Markdown from `https://docs.github.com/api/article/body?pathname=...`, fetched on 2026-11-22), code.visualstudio.com/docs (Markdown source from `microsoft/vscode-docs` branch `main`, pages marked `DateApproved: 11/18/2026`, with live pages spot-checked on 2026-11-22), the `github/copilot-cli` changelog (`changelog.md` on `main`, latest entry 1.0.114 on 2026-11-18), and github.blog/changelog. Every claim below was checked on 2026-11-22. A URL in the table is the page that owns the claim.

**Surfaces.** In this note, "CLI" is GitHub Copilot CLI. "VS Code" is agent mode in VS Code. "Cloud agent" is the agent that works on GitHub and opens PRs. The docs now call the former "coding agent" "Copilot cloud agent".

**Two facts changed a lot in 2026.** First, VS Code now runs agents on a chosen "harness". The **Copilot harness** is the default. It uses the same runtime and hook format as the CLI. The old **Local** harness is deprecated and "will be removed by February 2027". VS Code also has a **Claude** harness (the Claude Agent SDK) and a **Codex** harness. Second, on June 1, 2026 GitHub replaced premium requests with **usage-based billing in GitHub AI Credits**. Premium requests and model multipliers now apply only to old annual Pro and Pro+ plans.

## Summary

Shipinetics can port well to the Copilot CLI, and to VS Code when the session uses the Copilot harness, because both run one hook runtime: a `preToolUse` hook can deny a call (top-level `permissionDecision: "deny"`, or exit code 2), a `postToolUse` hook can add `additionalContext`, and subagent payloads carry `agentType`. So on those two surfaces the edit guard (test-writer only, protected files), the secrets guard, the PR gate, the install gate and the quick verify after a commit can all stay enforced by hooks. The CLI already reads much of the Claude Code layout (nested Claude hook groups, `.claude/settings.json`, `.claude-plugin/plugin.json`, `${CLAUDE_PLUGIN_ROOT}`, `.claude/skills`, `.claude/agents`, `.claude/commands`, `CLAUDE.md`), but our scripts must learn a third reply shape (top-level fields, not `hookSpecificOutput`) and Copilot's tool names and arguments. On every surface a hook that times out fails open, so the 60-second PR gate can be skipped, and VS Code hooks are still in preview. The cloud agent runs only `.github/hooks/*.json` from the default branch, with bash and no user or plugin hooks by default, so the guards work there only if each repository commits them. The cloud agent also can't run `git push` or `gh pr create` itself, so there the PR gate becomes CI required checks plus rulesets, and the install gate has nothing to ask. The task loop, routes, specs, reviews, evidence recording and writing rules stay instructions only, delivered as skills, `AGENTS.md` and custom agents that need Copilot model IDs such as `claude-opus-5.5` instead of `opus`.

## Table

| Row | Supported? (yes, partly, no, unverified) | How | Source (URL) |
|---|---|---|---|
| 1. Instruction files | yes | CLI: `.github/copilot-instructions.md`, `.github/instructions/**/*.instructions.md` (`applyTo`), `AGENTS.md`, `CLAUDE.md` (also `.claude/CLAUDE.md`), `GEMINI.md`, global `~/.copilot/copilot-instructions.md` and `~/.copilot/instructions/**/*.instructions.md`. VS Code (Copilot harness): `.github/copilot-instructions.md` or `AGENTS.md`, `.github/instructions`, nested `AGENTS.md`, the same `~/.copilot` user files. Cloud agent: repo-wide, path-specific, `AGENTS.md`/`CLAUDE.md`/`GEMINI.md`, and organization instructions | https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions , https://docs.github.com/en/copilot/reference/custom-instructions-support , https://code.visualstudio.com/docs/agents/reference/custom-instructions-reference |
| 2. Skills | yes | All three surfaces load `SKILL.md`. CLI project: `.github/skills`, `.agents/skills`, `.claude/skills`; personal: `~/.copilot/skills`, `~/.agents/skills` (not `~/.claude/skills`); plus plugins and `COPILOT_SKILLS_DIRS`. Invoked automatically by description, or as `/SKILL-NAME`. VS Code Copilot harness: `.github/skills`, `~/.copilot/skills`, shown in the `/` menu. Cloud agent: same project folders; personal skills only through a dotfiles repo | https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#skills-reference , https://docs.github.com/en/copilot/concepts/customizations/agent-skills , https://code.visualstudio.com/docs/agent-customization/agent-skills |
| 3. Prompt files / slash commands | partly | VS Code: `.github/prompts/*.prompt.md` run **only in the deprecated Local harness**; the docs say to convert them to skills. CLI: no prompt files; `.claude/commands/*.md` load as "commands" (an alternative skill format), and plugins can ship `commands`. Cloud agent: no prompt files | https://code.visualstudio.com/docs/agent-customization/prompt-files , https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#commands-alternative-skill-format , https://docs.github.com/en/copilot/reference/customization-cheat-sheet |
| 4. Custom agents and subagents | yes (cloud agent: partly) | `NAME.agent.md` (or `.md`) with YAML frontmatter: `description` (required), `name`, `tools`, `model`, `mcp-servers`, `infer`/`disable-model-invocation`, `user-invocable`. CLI adds `models`, `modelPolicy`, `reasoningEffort`, `include-custom-instructions`, `hooks`. Locations: `~/.copilot/agents`, `.github/agents`, `.claude/agents`, plugin `agents/`, org/enterprise `.github(-private)/agents`. CLI and VS Code delegate with the `task` tool; the subagent gets its own context window. Cloud agent ignores `model` and `handoffs`; the cheat sheet marks subagents unsupported on GitHub.com | https://docs.github.com/en/copilot/reference/custom-agents-configuration , https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#custom-agents-reference , https://code.visualstudio.com/docs/agents/reference/custom-agent-file-reference , https://code.visualstudio.com/docs/agents/run/subagents |
| 5. Hooks | yes (VS Code: preview) | One format for CLI, VS Code Copilot harness and cloud agent: JSON `{ "version": 1, "hooks": { ... } }` in `.github/hooks/*.json`, `~/.copilot/hooks/*.json`, inline `hooks` in `.github/copilot/settings(.local).json`, `~/.copilot/settings.json`, repo `.claude/settings(.local).json`, plugins, agent frontmatter. Events: `sessionStart`, `sessionEnd`, `userPromptSubmitted`, `userPromptTransformed`, `preToolUse`, `postToolUse`, `postToolUseFailure`, `agentStop`, `subagentStart`, `subagentStop`, `errorOccurred`, `preCompact`, `permissionRequest` (CLI), `notification` (CLI). JSON on stdin with `sessionId`, `timestamp`, `cwd`, `toolName`, `toolArgs` (PascalCase names give snake_case `tool_name`, `tool_input`). `preToolUse` can deny: `{"permissionDecision":"deny","permissionDecisionReason":"..."}` or exit 2. `postToolUse` can return `additionalContext`. Default `timeoutSec` 30; timeouts fail open. Cloud agent: only `.github/hooks/*.json` on the default branch, bash only, `ask` = deny | https://docs.github.com/en/copilot/reference/hooks-reference , https://code.visualstudio.com/docs/agent-customization/hooks |
| 6. Plugins | yes (cloud agent: partly) | CLI: `copilot plugin install ./my-plugin` (local path), `--plugin-dir=DIR` (load without install), `OWNER/REPO`, Git URL, `plugin@marketplace`. Manifest `plugin.json`, `.plugin/plugin.json`, `.github/plugin/plugin.json` or `.claude-plugin/plugin.json`. Built-in `awesome-copilot` marketplace; `copilot plugin marketplace add` takes a repo, URL or local folder. VS Code: install from a marketplace, a Git URL or a local folder; `chat.pluginLocations` (experimental) registers a folder; reads Copilot, Claude and Agent Plugins formats, and sees CLI-installed plugins. Cloud agent: `enabledPlugins` and `extraKnownMarketplaces` in `.github/copilot/settings.json` | https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference , https://code.visualstudio.com/docs/agents/reference/agent-plugin-reference , https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/configuring-agent-settings |
| 7. MCP | yes | CLI: `~/.copilot/mcp-config.json`, workspace `.mcp.json` and `.github/mcp.json` (trusted folders only), plugins, `--additional-mcp-config`; GitHub MCP server built in; not `.vscode/mcp.json`. VS Code Copilot harness: `~/.copilot/mcp-config.json` and workspace-root `.mcp.json` (`mcpServers` key); `.vscode/mcp.json` (`servers` key) is Local-only and can be forwarded. Cloud agent: repository settings JSON (`mcpServers`, tools only, no OAuth remotes), secrets prefixed `COPILOT_MCP_`, or `mcp-servers` in a custom agent | https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers , https://code.visualstudio.com/docs/agents/reference/mcp-configuration , https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/configure-mcp-servers |
| 8. Model selection | yes | CLI models include `claude-sonnet-5.5` (default), `claude-opus-5.5`, `claude-haiku-5.5`, `claude-haiku-4.5`, `gpt-5.4`, `gpt-5.3-codex`, `gpt-6-astra`, `gpt-6-luna`, `gpt-6.1-sol`, `gpt-6.1-terra`, `gpt-6.2-sol`, `gpt-6.2-astra`, `gemini-3.7-flash`, `gemini-3.8-flash`, `gemini-4-hydrogen`, plus `auto` and `fusion`. Global: `/config model`, `/model --global`, `model` in settings, `COPILOT_MODEL`. Per repo: `model` in `.github/copilot/settings.json`, `.github/allowed_models.txt`. Per session: `/model`, `--model`. Per agent: `model`/`models` frontmatter. VS Code: model picker, agent `model` + `model-policy`. Cloud agent: picker at task start (Auto, Claude, Gemini, GPT, Grok, MAI). Premium requests and multipliers are legacy since 2026-06-01 | https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#supported-models , https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli/choose-a-model , https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/changing-the-ai-model , https://docs.github.com/en/copilot/reference/copilot-billing/request-based-billing-legacy/model-multipliers-for-annual-plans |
| 9. Plans and usage | yes | Free (agent mode yes, cloud agent no, Auto model only), Student, Pro $10 (1,500 AI credits a month), Pro+ $39 (7,000), Max $100 (20,000), Business $19/seat (1,900 pooled), Enterprise $39/seat (3,900 pooled), "Copilot access" (no included credits). 1 AI credit = $0.01. All plans include Copilot CLI and agent mode. CLI subagent concurrency by plan: Free 2, Pro/Pro+ 4, Max 8, Business 16, Enterprise 32 | https://docs.github.com/en/copilot/get-started/plans , https://docs.github.com/en/copilot/concepts/billing-and-usage/individuals/billing , https://github.blog/changelog/2026-06-01-updates-to-github-copilot-billing-and-plans/ |
| 10. Transcripts | partly | CLI: `~/.copilot/session-state/<session-id>/events.jsonl` plus `~/.copilot/session-store.db` (SQLite). The changelog says usage metrics (requests, tokens, code changes) are written to `events.jsonl` when a session ends; the record schema is not documented. `/usage` shows per-model token totals and AI credits. `transcriptPath` is in `agentStop`, `subagentStart/Stop` and `preCompact` payloads. VS Code: local SQLite session store, JSON export, OTLP export of debug logs with token usage; no documented file path. Cloud agent: session log on GitHub.com | https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference#session-state , https://docs.github.com/en/copilot/concepts/security-governance-and-network-settings/session-data , https://github.com/github/copilot-cli/blob/main/changelog.md , https://code.visualstudio.com/docs/agents/run/sessions/session-history |
| 11. Permissions and sandbox | yes | CLI: `--allow-tool`/`--deny-tool` with `shell(git:*)`, `write(path)`, `read(.env)`, `url(host)`, `MCP(tool)`; deny beats allow, even with `--allow-all`; `--allow-url`/`--deny-url`, `allowedUrls`/`deniedUrls`; managed `permissions.deny/ask/allow`; `--available-tools`/`--excluded-tools`; OS sandbox (`/sandbox`, `--sandbox`). VS Code Copilot harness: Manual, Assisted or Allow all; `chat.tools.terminal.autoApprove` (`false` asks, it does not block); `chat.tools.urls.autoApprove`; terminal sandbox. Cloud agent: all tools pre-approved, firewall limits network | https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#tool-permission-patterns , https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference , https://code.visualstudio.com/docs/agents/run/approvals |
| 12. Non-interactive mode and PR gate | yes | CLI: `copilot -p "..."` (or piped stdin), `-s`, `--output-format json` (JSONL), `--no-ask-user`, `--allow-tool`, `--agent`, `--model`, `--share`; nonzero exit on interrupt or empty reply; repo hooks load only in trusted folders or with `--trust-folder`. Cloud agent: opens a draft PR on one `copilot/` branch, can't run `git push`, can't mark ready, approve or merge; it "is also subject to any branch protections and required checks"; workflows wait for **Approve and run workflows** by default; unattributed Copilot PRs need one extra approval | https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-programmatic-reference , https://docs.github.com/en/copilot/concepts/security-governance-and-network-settings/risks-and-mitigations , https://docs.github.com/en/copilot/how-tos/copilot-on-github/use-copilot-agents/review-copilot-output |

## 1. Instruction files

**CLI.** The CLI reads these files (checked 2026-11-22, https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions):

| Location | Scope and behavior |
|---|---|
| `$HOME/.copilot/copilot-instructions.md` | User-level instructions that apply across repositories. |
| `$HOME/.copilot/instructions/**/*.instructions.md` | Modular user-level instructions. |
| `.github/copilot-instructions.md` | Repository-wide instructions, discovered in the standard locations. |
| `.github/instructions/**/*.instructions.md` | Modular repository instructions, discovered in the standard locations but not intermediate directories. |
| `AGENTS.md` | Agent instructions, discovered in the standard locations. |
| `CLAUDE.md` | Agent instructions. "Copilot CLI also uses `.claude/CLAUDE.md`." |
| `GEMINI.md` | Agent instructions. |
| `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` | Additional `AGENTS.md` and `*.instructions.md` files. |

- "Standard locations" means the repository root, the current directory, the directories between them, and directories on the path of a file it works on.
- The CLI combines all files. It "does not define a general precedence order between these files."
- `@relative/path` in `copilot-instructions.md`, `AGENTS.md` or `CLAUDE.md` includes another file. Absolute and `~/` paths are not loaded.
- `/instructions` lists the files and turns single files on or off. `--no-custom-instructions` turns them all off.
- Path-specific frontmatter:

  ```markdown
  ---
  applyTo: "**/*.ts,**/*.tsx"
  excludeAgent: "code-review"
  ---
  ```

- A custom agent that runs as a subagent does **not** get repository instructions unless its frontmatter has `include-custom-instructions: true` (https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#repository-custom-instructions-for-subagents). The `general-purpose` subagent does get them.

**VS Code.** The harness decides which files load (https://code.visualstudio.com/docs/agents/reference/custom-instructions-reference):

| Harness | Project instructions | Targeted instructions |
|---|---|---|
| Copilot | `.github/copilot-instructions.md` or `AGENTS.md` | `.github/instructions/**/*.instructions.md` or nested `AGENTS.md` files |
| Claude | `CLAUDE.md` or `.claude/CLAUDE.md` | Markdown files in `.claude/rules` |
| Codex | `AGENTS.md` | `AGENTS.md` files along the path |
| Local (deprecated) | `.github/copilot-instructions.md`, `AGENTS.md`, or `CLAUDE.md` | `.github/instructions/**` or `.claude/rules` |

User instructions in the Copilot harness: `~/.copilot/copilot-instructions.md` and `~/.copilot/instructions/**/*.instructions.md`. The editor setting `chat.instructionsFilesLocations` still adds folders, but "Copilot CLI and the GitHub Copilot app don't inherit editor settings."

**Cloud agent.** It reads `.github/copilot-instructions.md`, `.github/instructions/**/*.instructions.md`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` and organization instructions (https://docs.github.com/en/copilot/reference/custom-instructions-support). Organization instructions need Business or Enterprise (https://docs.github.com/en/copilot/get-started/plans).

## 2. Skills

**CLI** (https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#skills-reference). Priority order, first found wins for a duplicate name:

| Location | Scope |
|---|---|
| `.github/skills/` | Project |
| `.agents/skills/` | Project |
| `.claude/skills/` | Project |
| Parent `.github/skills/` | Inherited (monorepo) |
| `~/.copilot/skills/` | Personal |
| `~/.agents/skills/` | Personal |
| Plugin directories | Plugin |
| `COPILOT_SKILLS_DIRS` | Custom |
| `--add-dir <path>` | Added root |
| (bundled with CLI) | Built-in |
| (org/enterprise) | Remote |

`~/.claude/skills` is **not** in the CLI list. Frontmatter fields: `name` (letters, numbers, hyphens, underscores, dots, colons, spaces; max 64; "Colons allow namespaced names (for example, `my-plugin:search`)"), `description` (max 1024), `argument-hint`, `allowed-tools`, `user-invocable`, `disable-model-invocation`. "When invoked (via `/SKILL-NAME` or automatically by the agent), the skill's content is injected into the conversation." Two plugins with the same skill name get "plugin-qualified invocation names such as `/my-plugin/search`". Commands: `/skills list`, `/skills info NAME`, `/skills reload`, `/skills add`, and outside a session `copilot skill list|add|remove|enable|disable`.

**VS Code** (https://code.visualstudio.com/docs/agent-customization/agent-skills). Supported folders per harness: Copilot `.github/skills/` and `~/.copilot/skills/`; Claude `.claude/skills/` and `~/.claude/skills/`; Codex `.agents/skills/` and `~/.agents/skills/`. The page says the table gives "a supported project and personal location for each harness, not every directory it recognizes." Skills show in the `/` menu. VS Code is stricter about `name`: "Only lowercase letters, numbers, and hyphens are allowed ... Do not use slashes, colons, dots, or namespace prefixes. Must match the parent directory name." For a plugin skill, "the plugin name is automatically used as a command prefix (for example, `/my-plugin:test-runner`)."

**Cloud agent** (https://docs.github.com/en/copilot/concepts/customizations/agent-skills). Project skills in `.github/skills`, `.claude/skills` or `.agents/skills`. "To make personal skills available in cloud sandbox sessions, include them in `.copilot/skills` in your dotfiles repository. This does not apply to GitHub Actions-based sessions."

## 3. Prompt files and custom slash commands

**VS Code.** Format `*.prompt.md` in `.github/prompts` (workspace) or the user profile (https://code.visualstudio.com/docs/agent-customization/prompt-files). Frontmatter: `description`, `name`, `argument-hint`, `agent`, `model`, `tools`. But: "Prompt files run only in **Local** harness sessions ... The Local harness is deprecated and will be removed by **February 2027**. Before then, convert existing prompt files to skills for use with the Copilot harness."

```markdown
---
name: review-api-security
agent: agent
description: Review a REST API implementation for common security risks
argument-hint: [API folder or file]
---
```

**CLI.** No prompt files (cheat sheet: Copilot CLI ✗, https://docs.github.com/en/copilot/reference/customization-cheat-sheet). Slash commands come from skills, and from "Commands ... stored as individual `.md` files in `.claude/commands/`. The command name is derived from the filename. Command files use a simplified format (no `name` field required) and support `argument-hint`, `description`, `allowed-tools`, and `disable-model-invocation`. Commands have lower priority than skills with the same name." Plugins can ship a `commands` path.

**Cloud agent.** No prompt files (cheat sheet: GitHub.com ✗).

## 4. Custom agents and subagents

**File format.** Markdown with YAML frontmatter, file `NAME.agent.md` or `NAME.md`. The ID is the file name without the extension; a subfolder adds `folder--` (https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli/invoke-custom-agents). Shared fields (https://docs.github.com/en/copilot/reference/custom-agents-configuration): `name`, `description` (required), `target` (`vscode` or `github-copilot`), `tools`, `model`, `disable-model-invocation`, `user-invocable`, `infer` (retired), `mcp-servers`, `metadata`. Body max 30,000 characters.

**Tool aliases** (case insensitive): `execute` (`shell`, `Bash`, `powershell`), `read` (`Read`, `NotebookRead`), `edit` (`Edit`, `MultiEdit`, `Write`, `NotebookEdit`), `search` (`Grep`, `Glob`), `agent` (`custom-agent`, `Task`), `web` (`WebSearch`, `WebFetch`), `todo` (`TodoWrite`). "All unrecognized tool names are ignored." So our `tools: Read, Grep, Glob, Bash` maps directly. `Skill` has no alias; the CLI tool is named `skill`.

**CLI extra fields** (https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#custom-agent-frontmatter-fields): `include-custom-instructions`, `models` (priority list), `modelPolicy` (`preferred` or `required`), `reasoningEffort`, and `hooks` (agent-scoped). Note: the how-to page spells it `model-policy: required` and adds `strict-tools-list: true`; the reference spells `modelPolicy`. VS Code uses `model-policy` and `reasoning-effort`.

```markdown
---
name: local-coder
description: >
  Use for small, well-defined coding tasks, such as a
  single-file change or a focused test fix.
model: LOCAL-PROVIDER/LOCAL-MODEL
model-policy: required
tools: ["read", "grep", "glob", "edit", "execute"]
strict-tools-list: true
include-custom-instructions: true
---
```

(https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-custom-agents-for-cli)

**Locations, CLI priority order:** `~/.copilot/agents/`, then `.github/agents/` (cwd up to Git root), then `.claude/agents/`, then `--add-dir` roots, then `<plugin>/agents/`, then org/enterprise remote agents. `~/.claude/agents` is not read by the CLI. Org agents live in `/agents` of the org's `.github` or `.github-private` repo; enterprise agents in a designated `.github-private` repo.

**VS Code locations** (https://code.visualstudio.com/docs/agents/reference/custom-agent-file-reference): `.github/agents` and `~/.copilot/agents` (Copilot format), `.claude/agents` and `~/.claude/agents` (Claude format: `tools`, `disallowedTools`, `model: sonnet|opus|haiku|inherit`, `permissionMode`, `skills`, `mcpServers`, `hooks`, `memory`). VS Code does not forward `model-policy`, `mcp-servers`, `github`, `deferred-tool-loading`, `strict-tools-list` or `include-custom-instructions` when it converts agents for the Copilot runtime. `handoffs` and `agents` are Local-only.

**Model per agent.** CLI: "When unset, inherits the outer agent's model. When the session model is set to `Auto` (server-selected), subagents always inherit the resolved session model regardless of this field." Precedence: per-call value, then the `subagents` override in `~/.copilot/settings.json` (or `/subagents`), then the agent's `model`/`models`/`reasoningEffort`, then the parent session. A model that can't be honored falls back to the session model, unless `modelPolicy: "required"`. Cloud agent: "If you are creating and using the agent profile in VS Code, JetBrains IDEs, Eclipse, or Xcode, you can also use the `model` property" (https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/create-custom-agents). So the cloud agent does not document `model`.

**Handoff and fresh context.** CLI: "When the main agent delegates work to a custom agent, that work is carried out by a subagent with its own context window." The main agent calls the `task` tool; `list_agents`, `read_agent` and `write_agent` coordinate running agents. The user can also pick an agent with `/agent` or `copilot --agent ID -p "..."`. Limits: depth 6 by default, concurrency by plan. "Subagents inherit permissions from the parent session and cannot escalate them." VS Code Copilot harness: "Copilot uses its native `task` tool for delegation" and a subagent "performs a focused task in its own context and returns a result to the main agent" (https://code.visualstudio.com/docs/agents/run/subagents). Cloud agent: the `agent` alias "Allows a different custom agent to be invoked", but the cheat sheet marks subagents ✗ for GitHub.com and ✓ for VS Code and CLI.

## 5. Hooks

Owner page: https://docs.github.com/en/copilot/reference/hooks-reference (checked 2026-11-22). VS Code says its Copilot harness, the GitHub Copilot app and the CLI "share this harness and its hook format" (https://code.visualstudio.com/docs/agent-customization/hooks). VS Code hooks are "in public preview" (https://docs.github.com/en/copilot/concepts/customizations/hooks).

**Locations.**

- CLI loads and combines: policy files (`/etc/github-copilot/policy.d/*.json`, root-owned), `.github/hooks/*.json`, `~/.copilot/hooks/*.json` (or `$COPILOT_HOME/hooks/`), inline `hooks` in `.github/copilot/settings.json` and `.github/copilot/settings.local.json`, "Cross-tool `.claude/settings.json` and `.claude/settings.local.json` files in the repository", inline `hooks` in `~/.copilot/settings.json`, and plugin `hooks.json` or `hooks/hooks.json`. Not `~/.claude/settings.json`.
- VS Code Copilot harness: the same sources. "Local settings such as `chat.useHooks` do not prevent the Copilot harness from loading a configuration."
- Cloud agent: "the only hook configuration that exists by default is `.github/hooks/*.json` inside the cloned repository. The sandbox does not ship with user-level hook files, `settings.json`, `config.json`, or installed plugins." The file "**must be present** on your repository's default branch" (https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-cloud-agent/use-hooks).
- Agent-scoped hooks (CLI only, and VS Code forwards them): a `hooks` map in a custom agent's frontmatter.
- Repository hooks need folder trust. In `-p` mode, use a trusted folder or `--trust-folder` (https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-programmatic-reference).

**Config format.**

```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [
      {
        "type": "command",
        "bash": "YOUR_BASH_COMMAND",
        "powershell": "YOUR_POWERSHELL_COMMAND",
        "cwd": "OPTIONAL/WORKING/DIRECTORY",
        "env": { "VAR": "VALUE" },
        "timeoutSec": 30
      }
    ]
  }
}
```

Fields: `type` (default `command`), `bash`, `powershell`, `command` (cross-platform fallback), `exec` + `args` (CLI only), `cwd`, `env`, `timeoutSec` (default 30), `timeout` (alias), `matcher`. There are also `http` hooks and `prompt` hooks (`sessionStart` only). The CLI changelog adds: "Hook config files now support Claude Code's nested matcher/hooks structure and optional type field" (1.0.6, 2026-03-16) and "Plugin hooks receive PLUGIN_ROOT, COPILOT_PLUGIN_ROOT, and CLAUDE_PLUGIN_ROOT env vars with the plugin's installation directory" (1.0.26, 2026-04-14) (https://github.com/github/copilot-cli/blob/main/changelog.md).

**Events and surfaces.**

| Event | Fires when | Output used | Cloud agent |
|---|---|---|---|
| `sessionStart` / `SessionStart` | New or resumed session | `additionalContext` | Fires once per job |
| `sessionEnd` / `SessionEnd` | Session ends | No | Fires once per job |
| `userPromptSubmitted` / `UserPromptSubmit` | User submits a prompt | Only SDK hooks | Fires at most once |
| `userPromptTransformed` | Prompt turned into model content | `modifiedTransformedPrompt` | Fires |
| `preToolUse` / `PreToolUse` | Before each tool | allow, deny, ask, `modifiedArgs` | Fires; `ask` = deny |
| `postToolUse` / `PostToolUse` | After a tool succeeds | `modifiedResult`, `additionalContext` | Fires |
| `postToolUseFailure` | After a tool fails | `additionalContext` | Fires |
| `agentStop` / `Stop` | Main agent ends a turn | `decision: "block"` forces another turn | Fires |
| `subagentStart` | Subagent spawned | `additionalContext` prepended to its prompt | Fires |
| `subagentStop` / `SubagentStop` | Subagent done | block, `modifiedResponse` | Fires |
| `errorOccurred` | Error | No | Fires |
| `preCompact` | Before compaction | No | Only `auto` |
| `permissionRequest` | Before the permission service | `behavior` allow or deny | No effect (CLI only) |
| `notification` | CLI notification | `additionalContext` | Does not fire (CLI only) |

VS Code lists `sessionStart`, `userPromptSubmitted`, `preToolUse`, `postToolUse`, `preCompact`, `subagentStart`, `subagentStop`, `agentStop` and `sessionEnd` for its Copilot harness.

**Payloads.** The event name picks the format. camelCase names get camelCase fields; PascalCase names get "VS Code compatible" snake_case fields.

```typescript
// preToolUse (camelCase)
{
    sessionId: string;
    timestamp: number;      // Unix ms
    cwd: string;
    toolName: string;
    toolArgs: unknown;
}

// PreToolUse (VS Code compatible)
{
    hook_event_name: "PreToolUse";
    session_id: string;
    timestamp: string;      // ISO 8601
    cwd: string;
    tool_name: string;
    tool_input: unknown;    // Tool arguments (parsed from JSON string when possible)
}
```

- The docs' own test input passes `toolArgs` as a JSON **string**: `{"timestamp":1704614400000,"cwd":"/tmp","toolName":"bash","toolArgs":"{\"command\":\"ls\"}"}` (https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-hooks). So with camelCase events, a script may need to parse `toolArgs` twice. With PascalCase events, `tool_input` is "parsed from JSON string when possible".
- The shell command is in `command`. The file-path key for `view`, `create` and `edit` is **unverified**; an SDK example uses `path`.
- Runtime tool names: `bash`, `powershell`, `view`, `create`, `edit`, `apply_patch`, `str_replace_editor`, `glob`, `grep`/`rg`, `web_fetch`, `task`, `ask_user`, `skill`. With PascalCase `PreToolUse`, matchers use Claude semantics and `tool_name` is the Claude name: `bash` → `Bash`, `view` → `Read`, `create` → `Write`, `edit`/`str_replace_editor`/`apply_patch` → `Edit`, `task` → `Agent`.
- Hooks that fire inside a subagent add `agentId`/`agent_id`, `agentType`/`agent_type` ("Subagent type, when known") and `parentAgentId`. "Root-agent hook inputs are unchanged."
- `postToolUse` adds `toolResult: { resultType: "success"; textResultForLlm: string }`.
- `agentStop`, `subagentStart`, `subagentStop` and `preCompact` carry `transcriptPath`. `sessionEnd` carries only `sessionId`, `timestamp`, `cwd` and `reason`.

**Can a pre-tool hook deny? Yes.** The reply is one top-level JSON object on stdout:

| Field | Values |
|---|---|
| `permissionDecision` | `"allow"`, `"deny"`, `"ask"` |
| `permissionDecisionReason` | "Reason shown to the agent. Required when decision is `"deny"`." |
| `modifiedArgs` | Replacement tool arguments |

```json
{
  "permissionDecision": "deny",
  "permissionDecisionReason": "This operation requires manual review."
}
```

- "Return `{}` for no decision." Returning `{}` "does not automatically approve the tool" (VS Code page).
- Exit code 2 denies, "even if that JSON reports `permissionDecision: "allow"`". Any other nonzero exit also denies ("fail-closed"), with "Denied by preToolUse hook (hook errored)".
- "Command hook **timeouts are always fail-open, even for `preToolUse` and admin-deployed policy hooks**."
- HTTP `preToolUse` hooks are fail-open on network errors.
- `ask` is denied under the cloud agent and in CLI autopilot mode.
- Print exactly one final JSON object. Two objects concatenate into invalid JSON and are ignored. Progress lines `{"type":"progress","message":"..."}` are allowed before it.
- VS Code migration guide: "Use the documented top-level `permissionDecision` ... Return `{}` when there is no hook decision" and "accepting a PascalCase input alias does not establish support for every Local `hookSpecificOutput` field. Emit the documented Copilot output" (https://code.visualstudio.com/docs/agent-customization/migrate-customizations).

**Can a post-tool hook add context? Yes.**

```typescript
{
    modifiedResult?: { resultType: "success"; textResultForLlm: string };
    additionalContext?: string;
}
```

"Additional guidance appended to `textResultForLlm` so the model sees it after the tool output on the same turn. When multiple hooks return `additionalContext`, the results are joined with a double newline and capped at 10 KB."

**Timeouts.** `timeoutSec`, default 30 seconds. No maximum is documented. On timeout the hook is killed and the run continues.

**Port mapping for Shipinetics.**

| Shipinetics hook | Copilot event (CLI, VS Code) | Cloud agent |
|---|---|---|
| `companions-notice.sh` (SessionStart) | `sessionStart`, `additionalContext` | Only if committed to `.github/hooks/` |
| `guard-edits.sh` (PreToolUse Edit/Write) | `preToolUse`, matcher `edit\|create\|apply_patch\|str_replace_editor`, or PascalCase `Edit\|Write` | Same, committed |
| `guard-secrets.sh` (PreToolUse Bash/Read) | `preToolUse`, `bash\|view` | Same, committed |
| `guard-pr.sh` (PreToolUse Bash, 60 s) | `preToolUse`, `bash`; needs `timeoutSec` above its run time | Not useful: the agent does not run `gh pr create` |
| `guard-installs.sh` (PreToolUse Bash) | `preToolUse`, `bash` | Not useful: no interactive approval |
| `verify-after-commit.sh` (PostToolUse Bash, 180 s) | `postToolUse`, `additionalContext` | Possible, counts against the job time |
| `usage-record.sh` (SessionEnd) | `sessionEnd` (no transcript path; derive `~/.copilot/session-state/<sessionId>/`) | Files are discarded at job end |

## 6. Plugins and extensions

**CLI** (https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference).

- Install specs: `plugin@marketplace`, `OWNER/REPO`, `OWNER/REPO:PATH/TO/PLUGIN`, a Git URL, or "Local path `./my-plugin` or `/abs/path`". `--plugin-dir=DIRECTORY` loads a plugin from a folder for one session without installing it.
- "When you install a plugin, its components are cached ... To pick up changes made to a local plugin, install it again" (https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/plugins-creating). But "Path-sourced plugins in a local (directory-source) marketplace load live from their real directory."
- Installed plugins live in `~/.copilot/installed-plugins/MARKETPLACE/PLUGIN-NAME` or `~/.copilot/installed-plugins/_direct/SOURCE-ID/`.
- Legacy manifest locations, in this order: `.plugin/plugin.json`, `plugin.json`, `.github/plugin/plugin.json`, `.claude-plugin/plugin.json`. Components: `agents/` (`.agent.md`), `skills/`, `commands`, `hooks` (`hooks.json` or `hooks/hooks.json`), `mcpServers` (`.mcp.json`), `lspServers`.
- Agent Plugins 1.0 (`$schema` `https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`): portable `skills/` and `mcp.json`; Copilot-only parts under `com.github.copilot/` (`agents/`, `commands/`, `rules/`, `hooks/hooks.json`, `lsp.json`).
- Marketplaces: built-in `awesome-copilot`; `copilot plugin marketplace add OWNER/REPO`, a URL, or `/PATH/TO/MARKETPLACE-DIRECTORY`. Manifest `marketplace.json`, `.plugin/marketplace.json`, `.github/plugin/marketplace.json` or `.claude-plugin/marketplace.json`. The docs use `copilot plugin marketplace add anthropics/claude-code` as an example.
- Plugin agents and skills lose to project or personal ones with the same ID or name.
- Experimental "extensions" also exist (`/extensions`), separate from plugins.

**VS Code** (https://code.visualstudio.com/docs/agents/reference/agent-plugin-reference, https://code.visualstudio.com/docs/agent-customization/agent-plugins).

| Plugin format | Manifest | Hook file | Root token |
|---|---|---|---|
| Agent Plugins 1.0 | `plugin.json` with `$schema` | `com.github.copilot/hooks/hooks.json` | `${PLUGIN_ROOT}` |
| Copilot | `plugin.json` | `hooks.json` (plugin root) | `${PLUGIN_ROOT}` or `${CLAUDE_PLUGIN_ROOT}` |
| Claude | `.claude-plugin/plugin.json` | `hooks/hooks.json` | `${CLAUDE_PLUGIN_ROOT}` |

- Install from a marketplace, or "Install a plugin from source": a Git URL or a local folder path (**Chat: Install Plugin from Source**).
- `chat.pluginLocations` (experimental) registers a folder without installing it: `{ "chat.pluginLocations": { "/path/to/my-plugin": true } }`.
- `chat.plugins.marketplaces` (experimental) adds marketplaces, including `file:///` paths.
- VS Code "automatically discovers plugins that you install with the Copilot CLI" from `~/.copilot/installed-plugins/`.
- Hook schema in a plugin must match the target runtime: "For Copilot sessions, use the Copilot hooks reference ... A plugin packages hooks; it does not translate Local harness scripts."

**Cloud agent** (https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/configuring-agent-settings).

```json
{
  "extraKnownMarketplaces": {
    "MARKETPLACE-NAME": {
      "source": { "source": "github", "repo": "OWNER/REPOSITORY" }
    }
  },
  "enabledPlugins": { "PLUGIN-NAME@MARKETPLACE-NAME": true }
}
```

in `.github/copilot/settings.json`. Whether the hooks of such a plugin run in a cloud job is unverified (see Open questions).

## 7. MCP

**CLI** (https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-mcp-servers, https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#mcp-server-loading-priority). Priority, highest first: `--additional-mcp-config`, plugin servers, workspace `.mcp.json` and `.github/mcp.json` (trusted folders only), `~/.copilot/mcp-config.json`. The GitHub MCP server is built in. Commands: `/mcp`, `copilot mcp add`. "The `.vscode/mcp.json` file for VS Code is not read by Copilot CLI." Migration: `jq '{mcpServers: .servers}' .vscode/mcp.json > .mcp.json`.

**VS Code Copilot harness** (https://code.visualstudio.com/docs/agents/reference/mcp-configuration). User: `$COPILOT_HOME/mcp-config.json` or `~/.copilot/mcp-config.json`. Shared: `.mcp.json` at the workspace root, with a top-level `mcpServers` object. "For new Copilot configurations, use these native destinations, not `.vscode/mcp.json` or profile `mcp.json`. Those files use the deprecated Local harness's ... `servers` format." Eligible definitions can be forwarded.

**Cloud agent** (https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/configure-mcp-servers). JSON with `mcpServers` in repository settings, shared with Copilot code review. Types `local`, `stdio`, `http`, `sse`. "Only MCP tools" (no resources or prompts). No OAuth remote servers. Secrets must be Agents secrets named `COPILOT_MCP_...`. A custom agent can declare `mcp-servers` in its frontmatter.

## 8. Model selection

**Model names, CLI** (https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#supported-models): `claude-sonnet-5.5` ("General-purpose coding (default)"), `gpt-5.4`, `gpt-6.2-sol`, `gpt-6.1-sol`, `gpt-6.1-terra`, `gpt-6.2-astra`, `gpt-6-astra`, `gpt-6-luna`, `claude-opus-5.5`, `claude-haiku-5.5`, `claude-haiku-4.5`, `gpt-5.3-codex`, `gemini-3.7-flash`, `gemini-3.8-flash`, `gemini-4-hydrogen`. Also `auto` and `fusion` (with `--fusion-tier standard|high|max`). Built-in agents name more models, for example `explore` on `gpt-5.6-luna`.

**Model names, cloud agent** (https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/changing-the-ai-model): Auto, Claude Opus 5.5, Claude Sonnet 5.5, Claude Haiku 4.5, Claude Haiku 5.5, Gemini 3.8 Flash, Gemini 4 Argon, Gemini 4 Carbon, Gemini 4 Hydrogen, Gemini 4 Neon, GPT-5.6 Luna, GPT-5.6 Sol, GPT-6 Astra, GPT-6 Luna, GPT-6 Sol, GPT-6.1 Sol, GPT-6.1 Terra, GPT-6.2 Astra, GPT-6.2 Sol, Grok 4.5, Grok 4.6, Grok 4.7, MAI Code 1.1 Flash, MAI Code 2, MAI Code 2 Flash. "Where a model picker is not available, Auto will be used automatically."

**How to choose.**

| Scope | CLI | VS Code | Cloud agent |
|---|---|---|---|
| Global | `/config model`, `/model --global`, `model` in `~/.copilot/settings.json`, `COPILOT_MODEL` | Model picker; org can set `chat.defaultModel` | — |
| Per repository | `model` in `.github/copilot/settings.json`; `.github/allowed_models.txt` allowlist | — | — |
| Per session | `/model`, `--model=MODEL`; reasoning `--effort low\|medium\|high\|xhigh\|max` | Model picker | Picker when the task starts |
| Per agent | `model`, `models`, `modelPolicy`, `reasoningEffort`; `/subagents` override | `model` (list), `model-policy`, `reasoning-effort` | Not documented |

"An explicit `--model` takes precedence over a custom agent's `model` unless the agent sets `model-policy: required`."

**Premium requests and multipliers.** "As of June 1, 2026, GitHub replaced request-based billing with usage-based billing, where the cost of an interaction depends on two things: the **model** and the **number of tokens consumed**" (https://docs.github.com/en/copilot/reference/copilot-billing/request-based-billing-legacy/what-changed-with-billing). Multipliers "apply only to Copilot Pro and Copilot Pro+ subscribers on an existing **annual plan**". Legacy multipliers: Claude Haiku 4.5 0.33, Claude Opus 4.8 27, Claude Sonnet 4.6 9, GPT-5.3-Codex 6, MAI-Code-1.1-Flash 0.25, MAI Code 2 1, MAI Code 2 Flash 0.33; code review 13 (https://docs.github.com/en/copilot/reference/copilot-billing/request-based-billing-legacy/model-multipliers-for-annual-plans). Per-token prices are at https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing (for example Claude Opus 5.5: $4.00 input, $20.00 output per 1M tokens).

## 9. Plans and usage

Official statements from https://docs.github.com/en/copilot/get-started/plans and https://docs.github.com/en/copilot/concepts/billing-and-usage/individuals/billing:

| Plan | Price | AI credits a month | Cloud agent | Agent mode | MCP | Models |
|---|---|---|---|---|---|---|
| Copilot Free | Free | "An allowance" | Not included | Included | Included | Auto model selection only |
| Copilot Student | Free | "An allowance" | Included | Included | Included | Auto model selection only |
| Copilot Pro | $10 | 1,000 base + 500 flex = 1,500 | Included | Included | Included | A selection of models |
| Copilot Pro+ | $39 | 3,900 + 3,100 = 7,000 | Included | Included | Included | Premium models |
| Copilot Max | $100 | 10,000 + 10,000 = 20,000 | Included | Included | Included | Priority access to premium models |
| Copilot Business | $19 per seat | 1,900 per user, pooled | Included | Included | Included | Premium models |
| Copilot Enterprise | $39 per seat | 3,900 per user, pooled | Included | Included | Included | Priority access |
| Copilot access | $0 with GHEC, or $10 | None included | Included | Included | Included | As Enterprise |

- "All plans include Copilot CLI and the Copilot app."
- "1 AI credit = $0.01 USD." Credits are billed for Copilot Chat, Copilot CLI, the cloud agent, Spaces, Spark and third-party coding agents. "Code completions and next edit suggestions are not billed in AI credits."
- Organization custom instructions, content exclusion and policy management are Business and Enterprise only. Audit logs: Pro+, Max, Business, Enterprise.
- "If you are on a paid Copilot plan, you qualify for a 10% discount on model costs while using auto model selection in Copilot Chat, or Copilot cloud agent."
- Announcement: https://github.blog/changelog/2026-06-01-updates-to-github-copilot-billing-and-plans/ ("Usage-based billing is now live for all users"; new Copilot Max plan).
- CLI subagent concurrency by plan: Free/Education 2, Pro/Pro+ 4, Max 8, Business 16, Enterprise 32, usage-based billing 32 (https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#subagent-limits).

## 10. Transcripts

**CLI.**

- "Copilot CLI and the GitHub Copilot app store the complete record of each session under `~/.copilot/session-state/`. They also store a subset of the data in a local SQLite database, referred to as the session store" (https://docs.github.com/en/copilot/concepts/security-governance-and-network-settings/session-data).
- "Contains session history data, organized by session ID in subdirectories. Each session directory stores an event log (`events.jsonl`) and workspace artifacts (plans, checkpoints, tracked files)" (https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference#session-state).
- Token usage: the CLI changelog says "Session usage metrics (requests, tokens, code changes) are now persisted to events.jsonl after each session ends" (0.0.422, 2026-03-05) and "A copilot -p run stopped by Ctrl+C or a signal now finishes writing the session's shutdown record (usage and code-change totals)" (1.0.107, 2026-11-06) (https://github.com/github/copilot-cli/blob/main/changelog.md). The event schema is not documented. Unverified: exact event names and fields.
- `/usage` shows "per-model token totals. For token-based-billing accounts, each model's row also shows its own AI credit consumption." `/context` shows context-window usage. `/chronicle cost-tips` analyzes token spend.
- Sessions sync to the GitHub account by default (`remoteExport` setting; org policy "Store local sessions in the Cloud").
- `--share=PATH` writes a Markdown transcript after a `-p` run.

**VS Code.** Copilot harness session history is kept in "a local SQLite database" (https://code.visualstudio.com/docs/agents/run/sessions/session-history). **Chat: Export Chat...** writes JSON. Agent Debug Logs show token usage and export to "an OpenTelemetry JSON file in OTLP format" (https://code.visualstudio.com/docs/agents/agent-troubleshooting/chat-debug-view). The on-disk path is not documented. Whether Copilot harness sessions in VS Code also write `~/.copilot/session-state/` is unverified.

**Cloud agent.** "The session log remains available on GitHub.com." Each agent commit links to the session log. Hook-written files "are discarded when the job ends."

## 11. Permissions and sandbox

**CLI** (https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference#tool-permission-patterns, https://docs.github.com/en/copilot/how-tos/copilot-cli/use-copilot-cli/allowing-tools).

| Kind | Example patterns |
|---|---|
| `memory` | `memory` |
| `read` | `read`, `read(.env)` |
| `shell` | `shell(git push)`, `shell(git:*)`, `shell` |
| `url` | `url(github.com)`, `url(https://*.api.com)` |
| `write` | `write`, `write(src/*.ts)` |
| SERVER-NAME | `MyMCP(create_issue)`, `MyMCP` |

```shell
# Allow all git commands except git push
copilot --allow-tool='shell(git:*)' --deny-tool='shell(git push)'
```

- "Deny rules always take precedence over allow rules, even when `--allow-all` is set."
- `write(PATH)` deny is "exact or trailing-path-segment match; no glob support yet".
- Other flags: `--allow-all-tools`, `--allow-all-paths`, `--allow-all-urls`, `--allow-all`/`--yolo`, `--allow-url`, `--deny-url`, `--available-tools`, `--excluded-tools`, `--add-dir`, `--secret-env-vars`.
- Settings: `allowedUrls`, `deniedUrls` in `~/.copilot/settings.json`; a repository can add `deniedUrls` but never remove them. Saved approvals in `permissions-config.json`.
- Managed (enterprise) rules: `permissions.deny` / `ask` / `allow` with `Shell(...)`, `Read(...)`, `Edit(...)`, `Write(...)`, `Domain(...)`. `Edit`/`Write` rules also catch shell redirections and `sed -i`. `permissions.disableBypassPermissionsMode: "disable"` blocks allow-all.
- File access defaults to the working directory and the temp directory. Shell commands get a safety analysis; read-only commands such as `cat` and `ls` are auto-approved.
- OS sandbox: `sandbox.enabled`, `/sandbox`, `--sandbox`, with `sandbox.userPolicy.filesystem.readonlyPaths|readwritePaths|deniedPaths` and `network.allowedHosts|blockedHosts`. Hooks run inside the sandbox too; policy hooks run on the host.
- Plan mode (`/plan`) blocks edits to project files, but "It's a safety net, not a guarantee."

**VS Code Copilot harness** (https://code.visualstudio.com/docs/agents/run/approvals). Permission levels: Manual (default), Assisted, Allow all; default via `chat.defaultConfiguration: { "approvals": "assisted" }`. Terminal rules in `chat.tools.terminal.autoApprove`, User settings only: `true` runs without asking, `false` "asks for confirmation rather than blocking it". URL approvals in `chat.tools.urls.autoApprove`. Terminal sandbox settings `chat.agent.sandbox.*` (https://code.visualstudio.com/docs/agents/run/agent-sandboxing). So in VS Code only a hook can hard-block a command.

**Cloud agent.** "The agent runs with all tool permissions pre-granted." Network goes through a firewall that by default allows only GitHub and Copilot hosts (https://docs.github.com/en/copilot/how-tos/copilot-on-github/customize-copilot/customize-the-firewall).

## 12. Non-interactive mode and the PR gate

**CLI** (https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-programmatic-reference, https://docs.github.com/en/copilot/how-tos/copilot-cli/automate-copilot-cli/run-cli-programmatically).

```bash
copilot -p 'Write a commit message in plain text for the staged changes' -s \
  --allow-tool='shell(git:*)'
```

- `-p PROMPT` / `--prompt`: "The CLI exits after completion, with a nonzero status if the run is interrupted or the model returns a completely empty final response."
- Useful flags: `-s`, `--output-format json` (JSONL), `--no-ask-user`, `--agent`, `--model`, `--allow-tool`, `--assisted-approval`, `--share`, `--share-gist`, `--autopilot`, `--mode plan|autopilot`.
- `--trust-folder` trusts "the working directory's hooks, workspace MCP servers, and repository plugin settings for a single new non-interactive session". Without trust, prompt mode "warns when untrusted folders skip repository hooks".
- `permissionRequest` hooks can approve or deny "especially useful in CLI pipe mode (`-p`)".
- CI auth: `COPILOT_GITHUB_TOKEN`, `GH_TOKEN` or `GITHUB_TOKEN`.
- The CLI also has `/delegate` (hand work to the cloud agent) and `/pr` commands.

**Cloud agent PRs** (https://docs.github.com/en/copilot/concepts/security-governance-and-network-settings/risks-and-mitigations):

- "In other cases, a new `copilot/` branch is created for Copilot, and the agent can only push to that branch. The agent is also subject to any branch protections and required checks for the working repository."
- "Copilot cloud agent can only perform simple push operations. It cannot directly run `git push` or other Git commands."
- "Draft pull requests created by Copilot cloud agent must be reviewed and merged by a human. Copilot cloud agent cannot mark its pull requests as "Ready for review" and cannot approve or merge a pull request."
- "By default, workflows are not triggered until Copilot cloud agent's code is reviewed and a user with write access to the repository clicks the **Approve and run workflows** button." Admins can turn off **Require approval for workflow runs** (https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/configuring-agent-settings).
- "Prevents the user who asked Copilot cloud agent to create a pull request from approving it." "When Copilot cloud agent opens a pull request under its own app identity, one more approval is required ... enabled by default in rulesets ... and always applies to branch protection rules."
- "If your repository requires pull request approvals, **your approval of a Copilot pull request won't count**" (https://docs.github.com/en/copilot/how-tos/copilot-on-github/use-copilot-agents/review-copilot-output).
- By default the cloud agent also runs security checks and asks Copilot code review for a second opinion before it finishes.

**What this means for the PR gate.** On the CLI and in VS Code, `guard-pr.sh` can keep blocking `gh pr create` and `gh pr ready` in a `preToolUse` hook. On the cloud agent, the agent opens the draft PR itself, so no shell command exists to block. The enforceable gate there is our `.github/workflows/verify.yml` made a required status check in a ruleset or branch protection. A human then clicks **Approve and run workflows** and marks the PR ready.

## Open questions

1. **Reply shape.** Does the Copilot runtime accept Claude's nested `hookSpecificOutput.permissionDecision`, or only the top-level fields? The docs say "emit the documented Copilot output". A safe plan: add a third branch in `sy_hook_pretool_reply` that prints top-level `permissionDecision`, and test whether exit code 2 with the same JSON also works in Claude Code.
2. **Harness detection.** How should `sy_hook_harness` recognize Copilot? camelCase payloads have `toolName`/`toolArgs`/`sessionId`. PascalCase payloads look like Claude's (`tool_name`, `tool_input`, `hook_event_name`, `session_id`) and need another marker. Test whether `COPILOT_HOOK_DEPTH`, `PLUGIN_ROOT` or `COPILOT_PLUGIN_ROOT` is in the environment (the changelog says plugin hooks get `PLUGIN_ROOT`, `COPILOT_PLUGIN_ROOT` and `CLAUDE_PLUGIN_ROOT`, and command hooks get `COPILOT_HOOK_DEPTH`).
3. **Tool argument keys.** What are the exact `toolArgs` keys for `view`, `create`, `edit`, `apply_patch` and `str_replace_editor`? Is the file path `path`? `apply_patch` can touch several files in one call, so the edit guard must parse the patch.
4. **Two hooks.json files.** Our repo has a Claude `hooks/hooks.json` and an Antigravity `hooks.json` at the root. The CLI reads "`hooks.json` or `hooks/hooks.json`" for legacy plugins. Which one wins, and does the Antigravity file (top key `shipinetics`) break plugin loading? VS Code says a Claude-format plugin uses `hooks/hooks.json`.
5. **`${CLAUDE_PLUGIN_ROOT}` in hook commands.** The CLI sets the variable in the environment. Does it also expand the token inside the `command` string, as Claude Code does? The changelog mentions expansion only for `cwd` and `env` values (`${COPILOT_PLUGIN_ROOT}`, 1.0.111).
6. **Test-writer detection.** What `agentType` does a plugin agent report: `test-writer`, `shipinetics:test-writer`, or another form? Our guard matches any type that ends in `test-writer`.
7. **Plugin agents with `.md` files and Claude frontmatter.** Do plugin agents load from `agents/*.md` (not `.agent.md`)? What happens to `model: opus`, `effort: high` and `color`? The docs say an unhonored model falls back to the session model, so we likely need Copilot IDs (`claude-opus-5.5`) and `reasoningEffort`.
8. **Skill names with a colon.** CLI skill names may contain colons; VS Code rejects them silently. Our skills are invoked as `shipinetics:<name>`. Check how each surface names plugin skills.
9. **Cloud agent and plugins.** Repository `enabledPlugins` is "also read by Copilot in the cloud", but the hooks reference says the cloud sandbox has no installed plugins by default. Do plugin hooks and agents run in a cloud job?
10. **Transcript schema.** What are the event names and token fields in `events.jsonl`? Does a VS Code Copilot harness session also write `~/.copilot/session-state/`?
11. **VS Code Claude harness.** Does the VS Code Claude harness load an installed Claude Code plugin (our `.claude-plugin/` hooks and agents) with Claude Code semantics? If yes, Shipinetics might run there unchanged. The docs only say "Sessions use Claude project configuration" and link to Claude's hook reference.
12. **Timeout ceiling.** Is there a maximum `timeoutSec`? A timed-out `preToolUse` hook fails open, so the PR gate's verify step must finish in time or record its pass earlier.
13. **Cloud agent subagents.** The cheat sheet marks subagents unsupported on GitHub.com, but the cloud agent maps the `agent` tool alias to "Custom agent" tools. Can the cloud agent call our reviewer and test-writer as subagents?
