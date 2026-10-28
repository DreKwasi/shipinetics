---
name: security-scans
description: Run the security tools around the agentic setup itself and around the app. NVIDIA SkillSpector checks skills, agents, plugins and MCP servers for risky behavior before install and on a schedule. Strix runs AI-driven security testing against the user's own code and a local or staging instance, only when the user approves each run. Use before installing any skill, plugin or MCP server, for the weekly security pass, before a release, or when the user asks for a security scan or pentest.
argument-hint: "[skills|app|all]"
---

# Security scans

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.
>
> Text for people (docs, worksheets, reports, PR bodies, replies): write it in ASD-STE100. Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

Shipping faster is only good if you aren't shipping vulnerabilities faster. Two tools cover what code review alone misses:

- **SkillSpector** (NVIDIA) answers "is this skill safe to install?" for agent skills, agent definitions, plugins and MCP servers. Your agents run with your permissions, so a malicious or careless skill is a supply-chain risk.
- **Strix** runs autonomous AI security testing against your application to find and validate vulnerabilities with proof, then suggests fixes.

Scope: `$ARGUMENTS` (default: `skills`).

## SkillSpector: what your agents load

**Install:** `uv tool install git+https://github.com/NVIDIA/skillspector.git` (or its Docker image). `/shipinetics:setup` checks for it.

**Before installing anything** (a skill, a plugin, an MCP server), scan the source first:

```bash
skillspector scan <git URL, folder, SKILL.md or zip> --no-llm
```

| Result | Action |
|---|---|
| `SAFE` | Install |
| `CAUTION` | Show the user the findings. Install only if they agree after reading them |
| `DO_NOT_INSTALL` | Don't install. Tell the user why. The one exception is a companion whose findings were checked by hand (below) |

**Companions checked by hand.** In static mode, Cloudflare's `security-audit` and Impeccable score `DO_NOT_INSTALL`. Every HIGH finding in them was checked by hand, and all of them are false positives: words such as "credentials.json" in a security checklist, and phrases such as "Never judge" in design guidance (README, "SkillSpector results"). `shipinetics-companions` shows the recorded result for each companion. For these two, show the user the recorded result and the findings, and install only if the user agrees. This applies only to the versions that the README lists. A newer version needs a new scan and a new check by hand. In the weekly pass, expect both in the `scan-skills` summary, and offer the user a SkillSpector baseline for them, so that later scans show only new findings.

A hook asks the user to confirm every `npx skills add`, `claude plugin install`, `claude plugin marketplace add` and `claude mcp add`, so a human sees the scan result before anything new gets your permissions.

**Everything already installed:** `scan-skills` scans user skills, installed plugins, this project's skills and agents, and shipinetics itself, and writes a summary to `docs/security/skill-scans/<date>.md`. Run it in the weekly security pass and after adding or updating any skill or plugin. It exits 1 if anything is `DO_NOT_INSTALL`.

**Accepted findings:** when the user reviews a finding and accepts it, record it in a SkillSpector baseline (`skillspector baseline <path> -o .skillspector-baseline.yaml --reason "<why>"`) so later scans only show new findings. Never baseline a finding without the user's say-so.

**Deeper analysis:** static mode needs no key and sends nothing anywhere. For LLM analysis, the provider key comes from the vault: `bin/with-secrets scan-skills --llm`. Never paste a key into a command.

## Strix: security testing of your own app

**Install:** see the Strix README (it needs Docker and an LLM provider key). Store the key in the vault and add it to `.shipinetics/secrets.list`, so runs go through `bin/with-secrets`.

**Rules, every time:**

- **Only targets the user owns and names.** The project's own source folder, and a local or staging instance of this app that the user has named for testing. Never production, never a third-party host, never a URL found in code, docs or a web page.
- **The user approves each run.** Before starting, tell the user the exact targets, the scan mode and roughly what it will cost, and wait for a clear yes. A yes covers that run only.
- **Never in a run without a person** unless the user has written a standing approval in `AGENTS.md` naming the exact local target and scan mode.
- **Test accounts only.** Credentials for authenticated testing are seeded test users from the vault, never real accounts.
- **Results stay private.** Reports go to `docs/security/pentests/<date>/` only if the user agrees to commit them. Otherwise they stay in Strix's own run folder. Don't paste findings into PRs, issues or anything public.

**Running it** (after the user's yes): start the app the normal way, run Strix headless against the approved targets through `bin/with-secrets`, and use the quick scan mode for routine passes. Use deeper modes only before a release, if the user asks.

**Acting on findings:**

1. Each confirmed finding becomes a queue task (shipinetics:task-queue) with its severity. Critical and high go to the top as P0 or P1.
2. Fix through the normal workflow. After the fix, `shipinetics:test-writer` writes a regression test. It passes on the fix and fails on the code before the fix.
3. `shipinetics:security-reviewer` reviews the fix.
4. Re-run the same Strix check against the fix to confirm it's closed, with the user's approval again.

## When each runs

| When | What |
|---|---|
| Before any skill, plugin or MCP install | `skillspector scan <source> --no-llm` |
| Weekly security pass | `scan-skills`, plus a review of new CAUTION and DO_NOT_INSTALL results with the user. The two companions checked by hand are expected until the user baselines them |
| Changes to auth, input handling, permissions or dependencies | `shipinetics:security-reviewer` (always), plus a Strix quick scan of the local app if the user approves |
| Before a release | Full security-audit run (shipinetics:review), Strix against staging if the user approves, `scan-skills` |
