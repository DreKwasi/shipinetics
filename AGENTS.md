# Instructions for agents that work on Shipinetics

This repository is the Shipinetics plugin itself. It isn't a project that `/shipinetics:setup` set up, so the plugin's hooks and gates don't apply here. Follow these rules instead:

- Read [CONTRIBUTING.md](CONTRIBUTING.md) before you change anything. It has the rules for scripts (bash 3.2), hooks, skills, agents, setup templates and tests.
- Run `bash tests/run.sh` before you say a change is done. On macOS, also run `/bin/bash tests/run.sh`.
- Add CHANGELOG entries under `## Unreleased`. Never change the version in `plugin.json` or `.claude-plugin/plugin.json`.
- Keep Claude Code (`hooks/hooks.json`, `.claude-plugin/`) and Antigravity (`hooks.json`, `plugin.json`) in step.
- Terms are in [GLOSSARY.md](GLOSSARY.md) when it exists, and decisions in `docs/adr/`. Use the same words.
- Write text for people by `skills/explain/plain-language.md`.
- Never put personal data in a file: no employer, project or ticket names, private paths, emails or tokens.
- Don't add AI attribution (such as `Co-Authored-By` lines for an agent) to commits or pull requests.
