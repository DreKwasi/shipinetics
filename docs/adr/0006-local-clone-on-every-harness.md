# A clone installs Shipinetics into each harness

Status: accepted. Claude Code and Antigravity are built (0.12.0). Codex, OpenCode and Copilot come next. Until then, `shipinetics install` says that they aren't supported yet.

Claude Code can install Shipinetics from its GitHub marketplace (`claude plugin marketplace add DreKwasi/shipinetics`). For one person on Claude Code, that stays the simplest way. All other harnesses use a clone, and so does a team that changes Shipinetics. `shipinetics install <harness>` fits the same skills, guards and tools to Claude Code, Antigravity, Codex, OpenCode or Copilot. It uses one adapter for each harness.

We chose one installer from a clone for two reasons:

- One set of rules and checks then works in each harness that a team uses.
- A team can change Shipinetics in its own clone (or fork), and install that.

When a harness can't enforce a guard, `shipinetics status` says so. The git hooks and CI then stay as the last line of checks.

Checked: 2026-11-28. Sources: [docs/research/harnesses.md](../research/harnesses.md).
