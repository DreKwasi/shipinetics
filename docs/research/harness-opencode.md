# OpenCode as a harness for Shipinetics

Checked: 2026-11-22

Sources: the docs at opencode.ai/docs (their Markdown versions, fetched on 2026-11-22), the config schema at opencode.ai/config.json, and the repository `anomalyco/opencode` at commit `4332e24fad949f3ec404fddd0050ec5d9606f74a` (branch `dev`, 2026-11-22). `github.com/sst/opencode` now redirects to `github.com/anomalyco/opencode`. Every claim below was checked on 2026-11-22. In the source links, `SRC` stands for `https://github.com/anomalyco/opencode/blob/4332e24fad949f3ec404fddd0050ec5d9606f74a`.

**Version warning.** OpenCode has two lines now. OpenCode 2 is the current release (v2.3.2, 2026-11-18), and its docs are at `/docs`. OpenCode 1 still gets fixes (v1.19.6, 2026-11-17), and its docs moved to `/v1/docs`. V2 reads V1 config, agents, commands and skills, but **V1 plugins do not run in V2**. This note targets V2. A short V1 section is near the end. Releases: https://github.com/anomalyco/opencode/releases. Migration guide: https://opencode.ai/docs/migrate-v1/.

## Summary

Shipinetics can port to OpenCode 2 with almost no loss of enforcement. A small TypeScript plugin can carry all the guards. Its `tool.execute.before` hook gets the tool name, the full input (the shell `command`, the edit `path`), the session ID and the **agent ID**. Throwing an error in that hook rejects the call, and the model sees the message. So the edit guard (test-writer only, protected files), the secrets guard and the PR gate stay enforced, and the plugin can call our bash scripts through a process call. The install gate's "ask" maps to the permission `evaluate` hook, which can turn a decision into `ask` or `deny`. The quick verify after a commit maps to `execute.after`, which can change the tool result that the model reads. The companions notice and the usage log map to the event stream (`session.created`, `session.idle`, `session.usage.updated`), and to session tokens and cost, which OpenCode keeps in SQLite. Skills (`SKILL.md`), `AGENTS.md`, commands and subagents with their own model, permissions and fresh context all work. But `${CLAUDE_PLUGIN_ROOT}` isn't replaced, skill IDs lose the `shipinetics:` prefix, and per-agent temperature has no effect in V2. The main risks: a new plugin API (V2 only, not V1), the edit guard must also parse the multi-file `patch` tool, and the guards' `SHIPINETICS_*` session variables must reach the shared background server, not only the user's terminal.

## Table

| Row | Supported? (yes, partly, no, unverified) | How | Source (URL) |
|---|---|---|---|
| 1. Instruction files | yes | `~/.config/opencode/AGENTS.md`, then every `AGENTS.md` from the workspace up to the project root (or home). `CLAUDE.md` is read in each folder that has no `AGENTS.md`. `~/.claude/CLAUDE.md` is read when there is no global `AGENTS.md`. The `instructions` array adds files, globs and URLs | https://opencode.ai/docs/instructions/ |
| 2. Skills | yes | `SKILL.md` folders or flat `.md` files from `.opencode/skills`, `~/.config/opencode/skills`, `.claude/skills`, `~/.claude/skills`, `.agents/skills`, `~/.agents/skills`, plus a `skills` config array of paths or URLs. Frontmatter: `name`, `description`, `metadata.opencode/autoinvoke`, `disable-model-invocation`. The model loads one with the `skill` tool. The user types `@skill-id` | https://opencode.ai/docs/skills/ |
| 3. Custom commands | yes | Markdown in `.opencode/commands/` or `~/.config/opencode/commands/`, or JSON under `commands`. Frontmatter `description`, `agent`, `model`, `subagent`. `$ARGUMENTS`, `$1`, and `` !`cmd` `` shell output | https://opencode.ai/docs/commands/ |
| 4. Agents and subagents | yes (temperature: partly) | Markdown in `.opencode/agents/` or `~/.config/opencode/agents/`, or JSON under `agents`. `mode: primary`, `subagent` or `all`. Ordered `permissions` rules per agent. `model: provider/model#variant` (the variant sets the reasoning effort). The `subagent` tool starts a child session with fresh context, always in the background. Agent `request.body` (temperature) is kept but not sent | https://opencode.ai/docs/agents/ , https://opencode.ai/docs/tools/ |
| 5. Hooks and plugins | yes | A V2 plugin (`Plugin.define({ id, setup(ctx) })`) registers `ctx.tool.hook("execute.before")` and `("execute.after")`, `ctx.permission.hook("evaluate")`, `ctx.shell.hook("create.before")`, session hooks, and `ctx.event.subscribe()`. A throw in `execute.before` rejects the call. `execute.after` can replace the result. The plugin runs in the Bun-based server and can start processes | https://opencode.ai/docs/build/plugins/server/ , SRC/packages/plugin/src/promise/tool.ts , SRC/packages/core/src/plugin/hooks.ts |
| 6. Packaging and install from a local folder | yes | Local plugin folders in `.opencode/plugins/` or `~/.config/opencode/plugins/` load by themselves. Or list a path, npm name or git spec in `plugins`. Config: `~/.config/opencode/opencode.json(c)`, `<project>/opencode.json(c)`, `<project>/.opencode/opencode.json(c)`, and a system folder | https://opencode.ai/docs/plugins/ , https://opencode.ai/docs/config/ |
| 7. MCP | yes | `mcp.servers.<name>` with `type: local` (command, stdio) or `type: remote` (url, OAuth by default). `opencode mcp add/list/auth` | https://opencode.ai/docs/mcp-servers/ |
| 8. Model selection | yes | Root `model: provider/model`. Per agent and per command `model: provider/model#variant`. A subagent with no model uses the parent's model. `opencode run --model`. `opencode models` lists models. `small_model` is a V1 field that maps to `agents.title.model` | https://opencode.ai/docs/models/ , https://opencode.ai/docs/agents/ , https://opencode.ai/docs/migrate-v1/ |
| 9. Plans and usage | partly | OpenCode is MIT-licensed. OpenCode Console sells pay-as-you-go credits for curated models, and Go plans cost $10, $40 and $20 per member per month. ChatGPT Plus or Pro sign-in is supported. Claude plans work only through "Claude Agent", which runs your installed Claude Code. GitHub Copilot uses device OAuth. The name "Zen" is now only a provider ID in one harness page | https://opencode.ai/docs/console/ , https://opencode.ai/docs/console/go/ , https://opencode.ai/docs/providers/ , https://opencode.ai/docs/claude-agent/ |
| 10. Transcripts | yes | SQLite database, usually `~/.local/share/opencode/opencode.db` (`opencode debug paths db`). Each assistant message has `tokens` (input, output, reasoning, cache read and write) and `cost` in USD. `opencode session export`, `opencode stats --cost --json` | https://opencode.ai/docs/troubleshooting/ , https://opencode.ai/docs/cli/ , SRC/packages/schema/src/session-message.ts |
| 11. Permissions | yes (sandbox: no) | Ordered `permissions` list of `{action, resource, effect}`. The last matching rule wins. Shell rules match each subcommand from a built-in scanner. `policies` can hard-deny. The docs describe no OS sandbox: shell runs with the user's full authority | https://opencode.ai/docs/permissions/ , https://opencode.ai/docs/policies/ |
| 12. Non-interactive, server, SDK, GitHub | partly | `opencode run` (with `--format json`, `--agent`, `--model`, `--auto`, `--standalone`). `opencode serve` plus an HTTP API, `@opencode/client` and the embedded `@opencode/sdk`. V2 docs show only a plain GitHub Actions job. The `/opencode` comment app and `opencode github install` are in the V1 docs only, and the `github/` action folder is gone from `dev` | https://opencode.ai/docs/cli/commands/ , https://opencode.ai/docs/build/sdk/ , https://opencode.ai/v1/docs/github/ |

## 1. Instruction files

Source: https://opencode.ai/docs/instructions/ (checked 2026-11-22).

- **Global and project.** OpenCode loads `~/.config/opencode/AGENTS.md`, then every `AGENTS.md` from the current workspace folder up to home. For a workspace outside home, it stops at the project root. The order in the prompt is global first, then nearest to farthest:

  ```text
  ~/.config/opencode/AGENTS.md
  packages/web/AGENTS.md
  packages/AGENTS.md
  AGENTS.md
  ```

- **Nested files** below the workspace load when the agent reads or lists a file in that area.
- **Live updates.** A change to a global or upward `AGENTS.md` during a session is sent as an "instruction update" before the next model request.
- **CLAUDE.md fallback**, quoted: "In any directory without an `AGENTS.md`, OpenCode reads `CLAUDE.md` instead. Without a global `~/.config/opencode/AGENTS.md`, it reads `~/.claude/CLAUDE.md`. A directory's `AGENTS.md` always wins over its `CLAUDE.md`." `OPENCODE_DISABLE_CLAUDE_CODE_PROMPT=1` skips every `CLAUDE.md`. `OPENCODE_DISABLE_CLAUDE_CODE=1` also skips `.claude` skills.
- **`instructions` config.** Extra files, globs, `~/` paths, absolute paths or HTTP(S) URLs. They load after the `AGENTS.md` files.

  ```jsonc
  {
    "$schema": "https://opencode.ai/config.json",
    "instructions": ["CONTRIBUTING.md", "docs/guidelines/*.md", "~/rules/opencode.md", "https://example.com/instructions.md"]
  }
  ```

- **Prompt order:** agent or provider system prompt, Code Mode guidance, MCP and skill guidance, `AGENTS.md` files then configured instructions, date and environment, then session entries from the API.

For Shipinetics: the setup template's `AGENTS.md` block works as is. A project that has only `CLAUDE.md` with an `@AGENTS.md` import gets the `CLAUDE.md` text. Whether OpenCode follows `@` imports inside it was not checked.

## 2. Skills

Source: https://opencode.ai/docs/skills/ (checked 2026-11-22).

- **Folders searched**, all four that we asked about, plus the global forms:

  | Scope | Sources |
  |---|---|
  | Global | `~/.config/opencode/skills` |
  | Global compatibility | `~/.claude/skills`, `~/.agents/skills` |
  | Project | `.opencode/skills` |
  | Project compatibility | `.claude/skills`, `.agents/skills` |

  Project folders are searched from the current folder up to the project root. V2 also reads the old singular `.opencode/skill/` (https://opencode.ai/docs/migrate-v1/).
- **Extra sources**: a `skills` array of local paths or HTTP catalogs (a base URL with `index.json`). In V1 this was `skills.paths` and `skills.urls`.

  ```jsonc
  { "skills": ["./team-skills", "~/shared/opencode-skills", "https://example.com/opencode/skills/"] }
  ```

- **Forms**: `<source>/name.md` at the root, or `<source>/.../name/SKILL.md` nested up to six levels. Hidden folders and `node_modules` are skipped.
- **ID**: the file path sets the ID, not `name`. `skills/teams/release/SKILL.md` has ID `release`. The docs recommend `^[a-z0-9]+(-[a-z0-9]+)*$` but V2 doesn't enforce it. A later source with the same ID wins. Precedence, low to high: built-in, `.claude/skills`, `.agents/skills`, `~/.config/opencode/skills`, project `.opencode/skills`, then `skills` entries.
- **Frontmatter**:

  | Field | Behavior |
  |---|---|
  | `name` | Display name. Defaults to the path-derived ID |
  | `description` | Summary shown to the model. Without it, the skill isn't advertised |
  | `metadata.opencode/autoinvoke` | `false` hides it from the model's list |
  | `disable-model-invocation` | `true` does the same |

  `license` and `compatibility` are accepted and ignored. The docs don't mention `argument-hint` (Shipinetics uses it). Unknown fields aren't described, so they're probably ignored (unverified).
- **Invocation**: at each step the model sees ID, name and description. It calls the `skill` tool with `{ "id": "git-release" }`. OpenCode checks the agent's `skill` permission, adds the body without frontmatter, and gives "the skill's base directory and a sample of up to ten supporting file paths". The user can type `@skill-id` in a prompt.
- **Permissions**: `{ "action": "skill", "resource": "internal-*", "effect": "deny" }`.

For Shipinetics:
- Skill IDs become `evidence`, `workflow` and so on. Text that says `shipinetics:evidence` must change, or the names can collide with other skills.
- `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` aren't replaced (no substitution is documented). The skill gets its base directory, so paths relative to the skill folder work.
- Our skills aren't in any searched folder, so install adds the clone's `skills/` folder to a `skills` entry in the global config.

## 3. Custom commands

Source: https://opencode.ai/docs/commands/ (checked 2026-11-22).

- Markdown: `~/.config/opencode/commands/<name>.md` (global) and `.opencode/commands/<name>.md` (project). `command/` (singular) still works. Nested paths become `/team/review`.
- JSON: under `commands` in any config file. Each one needs `template`.
- Fields: `template` (JSON only), `description`, `agent`, `model` (`provider/model#variant`), `subagent` (`true` runs in a background child session). `subtask` is a deprecated alias.
- Arguments: `$ARGUMENTS`, `$1`, `$2`. With no placeholder, the arguments are added after a blank line.
- Shell: `` !`git diff --stat` `` puts the command's output into the prompt. Quote: "Shell blocks run when OpenCode evaluates the command, outside the agent's tool permission flow."

```md
---
description: Review code for correctness
agent: plan
model: anthropic/claude-sonnet-5-5#high
---

Review $ARGUMENTS. Report bugs first.
```

A plugin can also register commands with `ctx.command.transform(editor => editor.add({ name, description, execute }))` (https://opencode.ai/docs/build/plugins/server/).

## 4. Agents and subagents

Sources: https://opencode.ai/docs/agents/ , https://opencode.ai/docs/tools/ , https://opencode.ai/docs/migrate-v1/ (checked 2026-11-22).

- **Where**: `~/.config/opencode/agents/<name>.md` and `.opencode/agents/<name>.md`, or JSON under `agents`. A nested path becomes part of the ID: `.opencode/agents/team/reviewer.md` is `team/reviewer`. The body is the system prompt.
- **Native V2 frontmatter** (same fields as a JSON entry): `description`, `mode`, `model`, `system` (JSON only), `permissions`, `steps`, `hidden`, `color` (six-digit hex), `disabled`, `request`.

  ```md
  ---
  description: Reviews changes for correctness and regressions
  mode: subagent
  model: anthropic/claude-sonnet-5-5#high
  permissions:
    - action: edit
      resource: "*"
      effect: deny
    - action: shell
      resource: "*"
      effect: deny
  ---

  Review the current changes. List findings in severity order with file and line references.
  ```

- **Modes**: `primary` (default for a new custom agent), `subagent` (only in a child session through the `subagent` tool), `all`.
- **Tools per agent**: V2 has no tool list. You deny actions in `permissions` (`shell`, `edit`, `read`, `glob`, `grep`, `webfetch`, `websearch`, `skill`, `subagent`). Agent rules are added after the global rules. Quote: "A custom subagent uses its own permissions, not a subset of its parent's permissions."
- **Model and reasoning**: `model: provider/model#variant`. Variants usually stand for reasoning effort (`#high`), and you can define your own in the provider config (https://opencode.ai/docs/models/). "A subagent uses its configured model, or inherits the parent session's model when none is configured."
- **Temperature**: not supported per agent in V2. Quote: "Agent `request.body` is kept but not sent to the model, so V1 `temperature`, `top_p`, and `options` have no effect there. Set them on a model variant instead."
- **V1 frontmatter** (`tools`, `permission`, `temperature`, `prompt`, `name`) is deprecated but still translated. A file that uses any V2 field (`permissions`, `request`, `system`, `disabled`) is read as V2, and its V1 fields are ignored.
- **How the main agent calls one**: the `subagent` tool takes `agent`, `description` and `prompt`, and an optional `sessionID` for a follow-up (source: SRC/packages/core/src/tool/plugin/subagent.ts). Quote from the tools page: "Subagents always run in the background. The call returns immediately with a `sessionID`, and the parent receives a `<subagent>` message when the child goes idle". The parent's `subagent` permission (resource = agent ID) controls which agents it may start.
- **Fresh context**: yes. Quote: "Subagents run with fresh context in their own child sessions." The nesting depth is 1 by default (`experimental.subagent_depth`).
- **Built-ins**: `build`, `plan` (primary), `general`, `explore` (subagent).

For Shipinetics: an installer must generate native agent files, as `bin/shipinetics-antigravity` does. It maps Claude `tools:` to `permissions` deny rules, `model: opus|sonnet` plus `effort` to `anthropic/<model>#<variant>`, and color names to hex. The guard can read the ID `test-writer` from the file name. A plugin can't add agents: `AgentEditor` has `list`, `get`, `default`, `update` and `remove`, but no `add` (SRC/packages/plugin/src/promise/agent.ts). So agents ship as files.

## 5. Hooks and plugins

Sources: https://opencode.ai/docs/build/plugins/ , https://opencode.ai/docs/build/plugins/server/ , https://opencode.ai/docs/build/plugins/migrate-v1/ , and source code (checked 2026-11-22).

### Shape and loading

```ts
import { Plugin } from "@opencode/plugin"

export default Plugin.define({
  id: "example",
  async setup(ctx) {
    await ctx.storage.set("loaded", true)
  },
})
```

`setup` runs when the plugin loads and may return a cleanup function. `ctx` is a full server client (sessions, permissions, agents, skills, MCP, storage) plus hooks and transforms. `ctx.location.directory` is the folder where the plugin loaded. `ctx.options` holds the options from config. The host provides `effect` and `@opencode/plugin` to plugins (SRC/packages/plugin/src/runtime-modules.ts), so a local plugin needs no `npm install` for the SDK. That is my reading of the code, not a documented claim.

### Hooks that exist (V2)

| Domain | Hook | What it does |
|---|---|---|
| `ctx.tool.hook` | `execute.before` | Read or replace `tool` and `input` before a call. A throw rejects the call |
| `ctx.tool.hook` | `execute.after` | Read the call's result or error. Can replace `result` |
| `ctx.permission.hook` | `evaluate` | Runs after config rules for `allow` and `ask` decisions. Can set `effect` to `allow`, `ask` or `deny`, with `message`. A configured `deny` is final and skips the hook |
| `ctx.shell.hook` | `create.before` | Change `command`, `cwd`, `timeout`, `shell`, `env` before a shell process starts |
| `ctx.session.hook` | `prompt`, `context`, `compaction`, `generate`, `title`, `fork`, `model.request`, `http.request`, `http.response`, `retry`, `experimental.model.resolve`, `experimental.ws.*` | Prompt admission, the system prompt and messages before each model call, raw requests |

The exact argument types, from SRC/packages/plugin/src/promise/tool.ts:

```ts
export interface ToolHooks {
  readonly "execute.before": {
    tool: string
    readonly info?: Info
    readonly codemode: boolean
    readonly sessionID: Session.ID
    readonly agent: Agent.ID
    readonly messageID: SessionMessage.ID
    readonly id: Tool.CallID
    input: unknown
  }
  readonly "execute.after": {
    readonly tool: string
    readonly info?: Info
    readonly codemode: boolean
    readonly sessionID: Session.ID
    readonly agent: Agent.ID
    readonly messageID: SessionMessage.ID
    readonly id: Tool.CallID
    readonly input: unknown
  } & (
    | { readonly status: "completed"; result: Tool.Result }
    | { readonly status: "error"; error: Tool.Error }
  )
}
```

`Tool.Result` is `{ output?, content?: string | Content[], metadata? }` (SRC/packages/schema/src/tool.ts).

Built-in tool names and inputs (https://opencode.ai/docs/tools/ and SRC/packages/core/src/tool/plugin/*.ts):

| Tool | Input fields | Permission action, resource |
|---|---|---|
| `shell` | `command`, `workdir`, `timeout`, `background` | `shell`, each subcommand from the scanner |
| `read` | `path`, `offset`, `limit` | `read`, the path |
| `edit` | `path`, `oldString`, `newString`, `replaceAll` | `edit`, the path |
| `write` | `path`, `content` | `edit`, the path |
| `patch` (some GPT models only) | `patchText` with `*** Add File`, `*** Update File`, `*** Delete File` sections | `edit`, every path in the patch |
| `subagent` | `agent`, `description`, `prompt`, `sessionID` | `subagent`, the agent ID |
| `skill` | `id` | `skill`, the skill ID |

The V1 example in the migration guide reads `input.filePath`. The V2 tools use `path`.

### Can a before-hook block a call?

Yes. A comment in SRC/packages/core/src/plugin/hooks.ts says: "Only tool execute.before may fail: a Tool.Error rejects the call before it runs." The Promise adapter turns any thrown error into a `Tool.Error` with the error's message (`toolError`, SRC/packages/plugin/src/promise/adapter.ts). The docs' own guard example:

```ts
await ctx.tool.hook("execute.before", (event) => {
  const input = event.input as { filePath?: string }
  if (event.tool === "read" && input.filePath?.includes(".env")) {
    throw new Error("Do not read .env files")
  }
})
```

The hook can also change `event.input` or `event.tool`. To ask instead of deny, use the permission `evaluate` hook and set `event.effect = "ask"`, or call `ctx.permission.assert(...)` with a custom action and add a config rule for it. The permissions doc says denials carry the reason "so the model sees it and continues".

The hook runs in the core tool executor for every call, including tools inside Code Mode `execute` programs (`codemode: true`, SRC/packages/core/src/tool.ts). So calls from child sessions (subagents) go through it too. I read this from the code and didn't test it.

### Can an after-hook add text the model sees?

Yes. In SRC/packages/core/src/tool.ts, the executor runs `execute.after` and then builds the tool's returned content from `afterEvent.result.content`. A plugin can add a line to `event.result.content`. Docs example:

```ts
await ctx.tool.hook("execute.after", (event) => {
  if (event.status === "completed") event.result = { ...event.result, metadata: { observed: true } }
})
```

Other ways to give the model context: `ctx.session.synthetic({ sessionID, text })`, and `ctx.session.instructions.entry.put({ sessionID, key, value })`, which renders as a `<context key="...">` block.

### Events (for session start and end)

`ctx.event.subscribe({ types: [...] })` gives the server's event stream. Event types in SRC/packages/schema/src (session-event.ts, permission.ts and others) include `session.created`, `session.idle`, `session.status`, `session.error`, `session.deleted`, `session.updated`, `session.tool.called`, `session.tool.success`, `session.tool.failed`, `session.usage.updated`, `session.usage.recorded`, `session.step.ended`, `session.compaction.ended`, `permission.asked`, `permission.replied`, `message.updated` and `config.updated`. The docs list no complete set. They point to the `V2EventEncoded` schema in the API reference.

### Can a plugin run our bash scripts?

Yes, most likely. The server is built with `Bun.build` and `compile` (SRC/packages/cli/script/build.ts), so plugins run on Bun. The migration guide replaces V1's `$` Bun shell helper with "import and manage the process API your plugin uses". A shim can call `Bun.spawn` or `node:child_process` with the hook's data as JSON on stdin, and map the script's reply to a throw or to `effect = "ask"`. No official example starts a child process, so this is my inference.

### Where plugins live

- Automatic: direct `.ts` or `.js` files and plugin folders in every `.opencode/plugins/` folder, and in `~/.config/opencode/plugins/`.
- Configured: `plugins` in `opencode.json(c)`, as an npm name, version, git spec, relative or absolute folder, or `file://` URL. A configured local path must be a folder. A path to a single file is skipped. Relative paths resolve from the config file.
- A local folder with a `package.json` (`name`, `exports`) loads through its exports. Without one, OpenCode uses `server` (else `index`) `.ts`, `.tsx` or `.js` at its root.
- `"-id"` turns a plugin off, and `*` and `.*` wildcards work. Changes in watched folders reload by themselves. `opencode plugin add|list|check|update|remove` manage package plugins.

## 6. Packaging and install from a local folder

Sources: https://opencode.ai/docs/plugins/ , https://opencode.ai/docs/config/ , https://opencode.ai/config.json (checked 2026-11-22).

- **Config files**, low to high precedence: `~/.config/opencode/opencode.json(c)`, then `opencode.json(c)` files from the farthest folder to the nearest, then `.opencode/opencode.json(c)` files in the same order. The system folder (`/Library/Application Support/opencode` on macOS, `/etc/opencode` on Linux) and macOS managed preferences win over all of these. The system and global folders also load `agents/`, `commands/`, `skills/` and `plugins/`.
- **Local plugin**: list the clone's plugin folder in the global config. Or link it into `~/.config/opencode/plugins/<name>/`.

  ```jsonc
  {
    "$schema": "https://opencode.ai/config.json",
    "plugins": ["/Users/me/Projects/shipyard/opencode", { "package": "./plugins/local", "options": { "strict": true } }],
    "skills": ["/Users/me/Projects/shipyard/skills"]
  }
  ```

- **npm or git**: `opencode plugin add @scope/name@1.2.0` or `opencode plugin add github:acme/plugin#main`. Exact versions stay pinned. Ranges and branches update every 24 hours.
- **Schema**: `opencode.ai/config.json` has both V1 and V2 keys, including `agent` and `agents`, `command` and `commands`, `plugin` and `plugins`, `permission` and `permissions`, `instructions`, `skills`, `mcp`, `model`, `small_model` and `policies`.

A Shipinetics installer for OpenCode would: link or list the plugin shim folder, add the `skills/` path, generate `~/.config/opencode/agents/*.md` from `agents/*.md`, and put `bin/` on the PATH of the server process (see Open questions).

## 7. MCP

Source: https://opencode.ai/docs/mcp-servers/ (checked 2026-11-22).

- Client support: tools, prompts, resources and instructions.
- V2 config uses `mcp.servers.<name>`. `disabled` replaces V1's `enabled`. Timeouts are split into `timeout.catalog` and `timeout.execution`.

  ```jsonc
  {
    "mcp": {
      "servers": {
        "everything": {
          "type": "local",
          "command": ["npx", "-y", "@modelcontextprotocol/server-everything"],
          "environment": { "MCP_API_KEY": "{env:MCP_API_KEY}" }
        },
        "context7": { "type": "remote", "url": "https://mcp.context7.com/mcp" }
      }
    }
  }
  ```

- CLI: `opencode mcp add <name> --url <url>`, `opencode mcp add <name> [--global] -- <command>`, `opencode mcp list`, `opencode mcp auth <name>`, `opencode mcp logout <name>`. Remote servers use OAuth by default.
- By default, agents reach MCP tools through Code Mode (`execute`). `codemode: false` lists them as direct tools. Permission action: `<server>_<tool>` (https://opencode.ai/docs/tools/).
- Plugins can add servers with `ctx.mcp.transform`.

The install gate matches `claude mcp add`. It would need to match `opencode mcp add` and `opencode plugin add` too.

## 8. Model selection

Sources: https://opencode.ai/docs/models/ , https://opencode.ai/docs/providers/ , https://opencode.ai/docs/cli/commands/ , https://opencode.ai/docs/migrate-v1/ (checked 2026-11-22).

- **Providers**: a catalog from models.dev, plus Bedrock, Vertex, Azure, Copilot, Ollama, LM Studio, vLLM, any OpenAI-compatible endpoint, and custom packages. Connect with `/connect` or `opencode auth login <provider>`.
- **Global default**: `"model": "anthropic/claude-sonnet-5-5"`. The root value keeps no `#variant`.
- **Per agent**: `model: provider/model#variant` in frontmatter, or `{ "providerID", "model", "variant" }` in JSON.
- **Per subagent**: the same field on the subagent. With none set, it uses the parent session's model.
- **Per command**: `model:` in the command. It wins over the agent's model.
- **Per run**: `opencode run --model openai/gpt-6.1-sol#high "..."`.
- **List models**: `opencode models`, or `/models` in the TUI.
- **small_model**: still in the schema as a V1 field. Quote: "`small_model` becomes the `model` selection for the built-in `title` agent. Native V2 configuration should use `agents.title.model` instead."
- **Variants**: named per-model settings, often reasoning effort, defined in `providers.<id>.models.<id>.variants[]` with `settings`, `headers` and `body`.

## 9. Plans and usage

Sources: https://github.com/anomalyco/opencode/blob/4332e24fad949f3ec404fddd0050ec5d9606f74a/LICENSE , https://opencode.ai/docs/console/ , https://opencode.ai/docs/console/go/ , https://opencode.ai/docs/console/models/ , https://opencode.ai/docs/console/billing/ , https://opencode.ai/docs/providers/ , https://opencode.ai/docs/claude-agent/ , https://opencode.ai/docs/models/ (checked 2026-11-22).

- **OpenCode itself**: MIT License. You bring a provider.
- **OpenCode Console** ("optional"): pay-as-you-go credits for "a list of models tested and verified by the OpenCode team", plus workspaces, budgets, policies and web search. Quote: "Console is free for any team size, with no seat fees. You pay only for usage, from prepaid credits".
- **Free models**: Console has free models. They need OpenCode, and `OPENCODE_DISABLE_FREE_MODELS=1` hides them.
- **OpenCode Go**: Go $10/month, Go Plus $40/month, Go Teams $20/member/month (2-member minimum), for open coding models.
- **Zen**: the current docs don't use "OpenCode Zen" as a product name. It appears only as the provider ID `opencode-zen` ("Pay-as-you-go") in the Hermes harness page (https://opencode.ai/docs/console/harnesses/hermes/). It seems to be the old name of Console pay-as-you-go (unverified).
- **ChatGPT**: quote: "Use a ChatGPT Plus or Pro plan instead of an OpenAI API key. Connect OpenAI, then choose Sign in with ChatGPT … Usage counts against your plan, so these models show no cost." Context is capped like Codex.
- **Claude**: through "Claude Agent", a page marked `noindex` in its frontmatter but live. Quote: "Use your Claude plan or another Claude Code login. Claude Agent runs Claude Code on your machine, so install Claude Code 2.1.248 or later and sign in first." OpenCode's tools, permissions and plugin hooks stay in charge. Claude Code's own hooks, `CLAUDE.md`, skills and MCP are not loaded. With a Claude subscription, no cost is shown. The docs describe no direct Anthropic OAuth sign-in for Claude plans.
- **GitHub Copilot**: device OAuth with a Copilot Chat entitlement.

## 10. Transcripts

Sources: https://opencode.ai/docs/troubleshooting/ , https://opencode.ai/docs/cli/ , https://opencode.ai/docs/cli/commands/ , source (checked 2026-11-22).

- **Where**: a SQLite database, usually `~/.local/share/opencode/opencode.db`. `XDG_DATA_HOME`, the release channel and `OPENCODE_DB` can change it. `opencode debug paths db` prints the path without starting a server. The docs say not to edit it and to back it up before you inspect it.
- **Format**: tables `session`, `session_message` (a JSON `data` column) and `session_part` (SRC/packages/core/src/session/sql.ts).
- **Tokens and cost**: the assistant message schema has `cost: Money.USD` and `tokens: { input, output, reasoning, cache: { read, write } }`, plus `agent` and `model` (SRC/packages/schema/src/session-message.ts, SRC/packages/schema/src/token-usage.ts). Compaction, title and generate calls write a `session.usage.recorded` event with their own cost and tokens (SRC/packages/schema/src/session-event.ts).
- **Tools**: `opencode session list --format json`, `opencode session export <id>` (JSON, with `--sanitize`), `opencode stats --cost --models --json`. The fields inside `session export` weren't checked.

`scripts/usage.py` can read the database read-only, or call `opencode stats --json`. Neither adds a model call.

## 11. Permissions

Sources: https://opencode.ai/docs/permissions/ , https://opencode.ai/docs/policies/ , https://opencode.ai/docs/tools/ (checked 2026-11-22).

- **V2 format**: an ordered list. The last matching rule wins. With no match, the effect is `ask`.

  ```jsonc
  {
    "$schema": "https://opencode.ai/config.json",
    "permissions": [
      { "action": "shell", "resource": "*", "effect": "ask" },
      { "action": "shell", "resource": "git status *", "effect": "allow" },
      { "action": "shell", "resource": "git push *", "effect": "deny" }
    ]
  }
  ```

- **Wildcards**: `*` (it matches `/` too) and `?`, over the whole value. A shell pattern that ends in ` *` also matches the bare command.
- **Per bash pattern**: shell resources are each "scanner-produced command string; compound commands may produce several". A command that the scanner can't parse (`eval`, bad syntax) fails when any shell deny rule applies. For an operation with several resources, any `deny` denies it.
- **Defaults**: every agent starts with allow-all, plus `ask` for `*.env` and `*.env.*` reads (`*.env.example` is allowed). `external_directory` is allowed by default in V2. V1 asked.
- **Per agent**: `agents.<id>.permissions`, added after the global rules.
- **V1 names**: `permission`, `bash`, `task` and `write`/`patch` became `permissions`, `shell`, `subagent` and `edit`.
- **Approvals**: `once`, `always` (saved as a project-scoped allow, never over a configured deny), `reject`.
- **Policies**: `policies` can turn `allow` or `ask` into `deny` after all rules. Global and Console policies win over project config.
- **Sandbox**: none is described. The tools page says "`shell` executes a command in the host user's shell" with "the host user's filesystem, process, and network authority". Snapshots (a separate git object store) let you undo file changes (https://opencode.ai/docs/snapshots/).

The `.claude/settings.json` deny rules (`git push --force`, `git reset --hard`, `gh pr merge`, `npm publish`, the `~/.ssh` reads) map straight to `shell` and `read` deny rules. Because shell rules match each subcommand, `cd x && git push --force` is covered better than in Claude Code.

## 12. Non-interactive mode, server, SDK and GitHub

Sources: https://opencode.ai/docs/cli/commands/ , https://opencode.ai/docs/cli/ , https://opencode.ai/docs/build/sdk/ , https://opencode.ai/docs/build/client/ , https://opencode.ai/v1/docs/github/ (checked 2026-11-22).

- **`opencode run "<prompt>"`** has these flags: `--model`, `--agent`, `--continue`, `--session <id>`, `--file`, `--format json` (newline-delimited JSON), `--auto` ("Auto-approve permissions that are not explicitly denied"), `--archived`, `--standalone` (private server).
- **Server**: by default, every client uses one shared background server per user. Quote: "which owns sessions, configuration, integrations, permissions, and tool execution." Use `opencode serve [--hostname --port --cors]`, `opencode service start|stop|restart|set env`, `opencode reload`, and `opencode api <op>`. HTTP Basic auth uses `OPENCODE_PASSWORD`.
- **SDK**: `@opencode/client` is the HTTP client. `@opencode/sdk` (`OpenCode.create()`) runs OpenCode inside your process with no HTTP listener. Both are new in V2. The V1 server API is a breaking change.
- **ACP**: `opencode acp` serves editors over stdio.
- **GitHub and PRs**:
  - The V2 docs show only a plain GitHub Actions job that runs `opencode run --standalone --model ... "Review this repository..."` on `pull_request`.
  - The `/opencode` and `/oc` comment bot, `opencode github install`, the `opencode-agent` GitHub app and `uses: anomalyco/opencode/github@latest` appear only in the V1 docs.
  - The `github/` folder with `action.yml` exists at tag `v1.19.6` but not on `dev`, and the V2 CLI source has no `github` command.
  - Agents open PRs with `gh` through the shell tool, so the PR gate still applies.

## OpenCode 1 differences (for users who stay on V1)

Source: https://opencode.ai/v1/docs/plugins/ and https://opencode.ai/docs/build/plugins/migrate-v1/ (checked 2026-11-22).

- **Plugins**: a V1 plugin is a function that returns hooks by name: `"tool.execute.before": async (input, output) => {...}`, with `input.tool` and `output.args`. A throw blocks the call. V1 lists events such as `session.created`, `session.idle`, `permission.asked`, `tool.execute.before/after`, `shell.env` and `file.edited`. The context has a `$` Bun shell helper.
- **Config**: `plugin` (singular), `permission` with `bash`, agent `tools` maps and `temperature`.
- **One package for both**: a package can serve both lines from one default export, with `server()` for V1 and `setup()` for V2. V1 supports this from 1.18.29.

## Open questions

1. **Session env variables.** The guards read `SHIPINETICS_*` variables per session. In OpenCode the shared background server runs the tools and the plugin, so variables set in the user's terminal may not reach it. The docs say to use `opencode service set env` or `--standalone`. Check what `process.env` the plugin sees, and what env a shell call gets.
2. **PATH for `bin/`.** The same issue applies to putting Shipinetics `bin/` on the PATH. A `shell` `create.before` hook could add it to `event.env.PATH`. That needs a test.
3. **Process calls from a plugin.** No official example starts a child process from a V2 plugin. Test that `Bun.spawn` or `node:child_process` works in the compiled server, and check its timing against the 10 to 60 second timeouts our hooks use.
4. **Hooks in child sessions.** The code suggests that `execute.before` runs for subagent calls and Code Mode calls. Test it with a test-writer subagent.
5. **Edit and patch paths.** The `edit` and `write` `path` can be relative. `patch` lists several files in `patchText`. The edit guard must resolve the paths against the session folder and parse the patch headers. Check whether `info` or `ctx.session.get` gives the session folder.
6. **`argument-hint` and unknown skill fields.** Not documented. Check that they're ignored and don't break loading.
7. **`CLAUDE.md` imports.** The docs don't say whether OpenCode follows `@AGENTS.md` imports inside a fallback `CLAUDE.md`.
8. **Skill ID collisions.** Shipinetics IDs such as `review`, `testing` and `workflow` may clash with other skills in `.claude/skills` or `.agents/skills`. The `skills` config entries load last and win, but a prefix may still be safer.
9. **Live docs and repository.** The live Markdown pages matched the repository docs for every page checked (skills, agents, permissions, plugins server). The full event list is in the API reference (`/docs/api`, a redirect), which I didn't read.
10. **V1 transcripts.** I didn't check where V1 stores sessions or in what format.
