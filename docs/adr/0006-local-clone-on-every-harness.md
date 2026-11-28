# A clone installs Shipinetics into each harness

Status: accepted. Claude Code and Antigravity are built (0.12.0). Codex, OpenCode and Copilot come next; until then `shipinetics install` says they aren't supported yet.

Claude Code can install Shipinetics from its GitHub marketplace (`claude plugin marketplace add DreKwasi/shipinetics`), and that stays the simplest way for one person on Claude Code. Every other harness, and a team that changes Shipinetics, uses a clone: `shipinetics install <harness>` fits the same skills, guards and tools to Claude Code, Antigravity, Codex, OpenCode or Copilot through an adapter for each harness. We chose one installer from a clone so that one set of rules and checks works in every harness a team uses, and so that a team can change Shipinetics in its own clone (or fork) and install that. Where a harness can't enforce a guard, `shipinetics status` says so, and the git hooks and CI stay the backstop.

Checked: 2026-11-28. Sources: [docs/research/harnesses.md](../research/harnesses.md).
