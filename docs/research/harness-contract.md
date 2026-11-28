# What Shipinetics needs from a harness

Checked: 2026-11-22, against this repo at branch `post-commit-verify-and-evidence-setting`.

This note lists what Shipinetics uses from the harness that runs it. Each harness adapter (Claude Code, Antigravity, and later Codex, OpenCode and Copilot) must provide each item, or say which guard becomes an instruction only. The research notes `harness-codex.md`, `harness-opencode.md` and `harness-copilot.md` compare each tool with this list.

## Parts that need no harness

These work the same for every harness, because git, CI or a shell runs them:

- The git hooks from setup: `pre-commit` (lint fix, 400-line limit), `commit-msg` (`Worksheet:` trailer), `pre-push` (complete verify). Source: `skills/setup/templates/`.
- CI: `skills/setup/templates/github/workflows/verify.yml`.
- The tools in `bin/` (`shipinetics-verify`, `evidence`, `worksheet`, `shipinetics-config`, `known-failing`, `bench-compare` and the others). They need the plugin's `bin/` on the PATH.

## Parts that need the harness

| Need | Where Shipinetics uses it | What happens without it |
|---|---|---|
| Instruction file that loads each session | `AGENTS.md` with the Shipinetics block (`skills/setup/templates/AGENTS.md`); `CLAUDE.md` imports it | The agent doesn't know the rules |
| Skills (SKILL.md folders) | `skills/*/SKILL.md` (22 skills) | The task loop and every procedure are unknown |
| Skill text can find the plugin folder | 32 uses of `${CLAUDE_PLUGIN_ROOT}` and 4 of `${CLAUDE_SKILL_DIR}` in 23 files under `skills/` and `agents/` | Paths to templates, the plain-language guide and scripts don't resolve. Antigravity has this gap today: `bin/shipinetics-antigravity` replaces the variable only in the generated agents, not in the skills it links |
| Subagents with their own context, tools and model | `agents/*.md`: test-writer, test-plan-reviewer, reviewer, security-reviewer, ui-reviewer, live-tester. Frontmatter sets `tools`, `model` (opus or sonnet) and `effort` | No independent tests or reviews. Antigravity drops `model` and `effort` today |
| Hook before a shell command, that can deny it with a reason | `scripts/guard-secrets.sh`, `scripts/guard-pr.sh`, `scripts/guard-installs.sh` | The secrets guard, the PR gate and the install gate become instructions only |
| Hook before a file edit, that can deny it | `scripts/guard-edits.sh` (test files, protected files) | Independent tests and protected files become instructions only |
| The hook knows which subagent made the call | `guard-edits.sh` lets only an agent type that ends in `test-writer` edit tests (`sy_hook_agent_type`, `scripts/lib.sh`) | The edit guard can't tell test-writer from the main agent. Either it blocks test-writer too, or it can't enforce the rule |
| Hook after a shell command, that can add text for the model | `scripts/verify-after-commit.sh` (Claude Code only) | The agent runs `shipinetics-verify quick` itself, as the workflow skill says |
| Hook at session start, that can show a message and add context | `scripts/companions-notice.sh` | No notice about missing companions |
| Hook at session end or stop | `scripts/usage-record.sh` | No automatic token log; `shipinetics-usage` can still backfill from transcripts |
| Readable transcripts with token counts | `scripts/usage.py` reads Claude Code and Antigravity transcripts | No usage report for that harness |
| A way to install from a local clone | `bin/shipinetics-antigravity install` links the clone and generates native agents | Manual copying |

## Hook input fields that Shipinetics reads

From `scripts/lib.sh` (`sy_hook_*` functions). A new harness needs a mapping for each:

| Meaning | Claude Code | Antigravity |
|---|---|---|
| Tool name | `tool_name` | `toolCall.name` |
| Shell command | `tool_input.command` | `toolCall.args.CommandLine` |
| File path of an edit | `tool_input.file_path`, `tool_input.notebook_path` | `toolCall.args.Path`, `TargetFile`, `AbsolutePath`, `NotebookPath` |
| Working folder | `cwd` | `workspacePaths[0]` |
| Subagent type | `agent_type` | `agentType` |

## Hook replies that Shipinetics sends

| Reply | Claude Code | Antigravity |
|---|---|---|
| No opinion | empty output | empty output |
| Deny or ask before a tool | `hookSpecificOutput.permissionDecision` with a reason | `{decision, reason}` |
| Message and context at session start | `systemMessage` and `hookSpecificOutput.additionalContext` | `injectSteps` |
| Context after a tool | `hookSpecificOutput.additionalContext` (PostToolUse) | not wired |

## Models in use today

`agents/*.md` names Claude models only: `opus` for test-writer, reviewer, security-reviewer and ui-reviewer, `sonnet` for test-plan-reviewer and live-tester. The plan-aware design replaces these names with roles and a model catalog for each harness.
