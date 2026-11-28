# Instructions for agents that work on Shipinetics

This repository is the Shipinetics plugin itself. `/shipinetics:setup` did not set up this repository, so the hooks and gates of the plugin don't apply here. Follow these rules instead:

- Read [CONTRIBUTING.md](CONTRIBUTING.md) before you change anything. It has the rules for scripts (bash 3.2), hooks, skills, agents, setup templates and tests.
- Run `bash tests/run.sh` before you say that a change is done. On macOS, also run `/bin/bash tests/run.sh`.
- Add CHANGELOG entries under `## Unreleased`. Never change the version in `plugin.json` or `.claude-plugin/plugin.json`.
- Keep the Claude Code files (`hooks/hooks.json`, `.claude-plugin/`) and the Antigravity files (`hooks.json`, `plugin.json`) in step.
- The terms are in [GLOSSARY.md](GLOSSARY.md), when it exists. The decisions are in `docs/adr/`. Use the same words as these files.
- Write text for people by the rules in `skills/explain/plain-language.md`.
- Never put personal data in a file: no employer, project or ticket names, private paths, emails or tokens.
- Don't add AI attribution (such as `Co-Authored-By` lines for an agent) to commits or pull requests.
