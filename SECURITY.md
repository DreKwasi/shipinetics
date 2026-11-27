# Security Policy

## Supported versions

Shipinetics fixes security issues in the latest release only. Update to it before you report a problem, if you can.

## Reporting a vulnerability

Do not open a public GitHub issue for a security vulnerability.

Report it privately using GitHub Security Advisories:
https://github.com/DreKwasi/shipinetics/security/advisories/new

Include:

- The affected file, hook or CLI tool, and the Shipinetics version.
- Steps or a minimal payload to reproduce the issue.
- The impact (for example: bypassing a guard, leaking a secret, arbitrary command execution, or XSS in the usage HTML page).

## Scope and known limits

In scope:

- Bypasses in `scripts/guard-secrets.sh`, `scripts/guard-edits.sh`, `scripts/guard-pr.sh`, and `scripts/guard-installs.sh` that contradict their documented guarantees.
- Injection or unsafe path handling in `bin/*`, `scripts/*`, or `skills/setup/templates/*`.
- Localhost binding or XSS issues in `scripts/usage.py` and `scripts/usage-page.html`.

Known architectural limits (documented in [README.md](README.md#known-limits)):

- The guards inspect tool arguments and command text. They are not an OS sandbox, so an agent can bypass text-matching guards by writing and running a script. Use OS sandboxing (Antigravity's Seatbelt sandbox) or `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` (Claude Code) as the underlying boundary.
- `bin/shipinetics-usage serve` binds only to `127.0.0.1` and is intended for single-user local machines.
