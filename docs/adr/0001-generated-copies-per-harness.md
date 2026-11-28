# Each harness gets generated copies of the skills and subagents

Status: accepted. Built for Antigravity in 0.12.0. The model for each model role comes with the model catalog ([0007](0007-models-by-role.md)); until then the generated subagents carry no model.

The clone's `skills/` and `agents/*.md` stay the one source, written for Claude Code. For each other harness, `shipinetics install <harness>` writes copies in that harness's own format: subagent files in its syntax, with the model for each model role, and skill text with `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_SKILL_DIR}` replaced by real paths. We chose this because only Claude Code replaces those variables in skill text (Antigravity, Codex and OpenCode don't, and Copilot is unverified), and no harness reads another's subagent format with models intact. The cost is a refresh after each update, so the session-start notice says when a copy is older than the clone.

Checked: 2026-11-22. Sources: [docs/research/harnesses.md](../research/harnesses.md).

## Considered options

- **Link the clone's files, as the Antigravity installer did.** No refresh is needed, but paths in skill text don't resolve, and subagents lose their model.
- **Change every skill to avoid plugin paths** (for example, a command that prints the plugin folder). It works everywhere, but it changes 23 files, and each read of a template costs the agent an extra step.
