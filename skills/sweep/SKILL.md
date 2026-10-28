---
name: sweep
description: Periodic sweep across recent commits looking for problems no single review sees, like duplication between tasks, drifting patterns, half-finished migrations and stale docs. Use weekly, or when the user runs /shipinetics:sweep.
argument-hint: "[since: date, ref or 'last-sweep']"
---

# Commit sweep

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.
>
> Text for people (docs, worksheets, reports, PR bodies, replies): write it in ASD-STE100. Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

Per-task reviews look at one diff. Problems that span diffs slip through: two agents writing the same helper on different days, a pattern that drifts a bit with each change, a migration started and never finished. A sweep reads across commits to catch those.

Range: `$ARGUMENTS`. Default is since the last sweep tag: `git describe --tags --match 'sweep/*' --abbrev=0`. If there's no sweep tag, use the last 7 days.

## Gather

```bash
git log --oneline <since>..HEAD
git diff --stat <since>..HEAD
git log <since>..HEAD --format='%h %s%n%b' | grep 'Worksheet:' | sort -u
```

Read the worksheets for the period (their summaries and decisions), then read the combined diff by area.

## Look for

- **Duplication across tasks:** the same helper, type, query or component written twice. `rg` for similar names and shapes.
- **Pattern drift:** the same problem solved in different ways in different commits (error handling, data fetching, validation). Which one does `docs/conventions.md` say? If it says nothing, should it?
- **Half-finished work:** migrations started and not completed, feature flags never removed, old and new code paths both live, TODOs added and never queued.
- **Docs drift:** system docs whose 7-line headers no longer match the code after several small changes.
- **Design-system drift** (UI projects): `design-check --all` for values outside DESIGN.md, and Impeccable's `doctor` for a DESIGN.md that's incomplete or many commits behind the code. Collect the period's design-system change requests from worksheets: approved ones need a `/impeccable document` refresh, open ones need the human.
- **Test gaps:** behavior added across several commits that's only tested in pieces, or not at all end to end.
- **Dependency creep:** new packages, especially several that do the same job.
- **Complexity hot spots:** files changed in many commits this period. Churn often means a missing abstraction or a confusing module.
- **Worksheet follow-ups** that never made it into the queue.
- **Review dispositions** marked "deferred" whose queue task doesn't exist.
- **Guardrails not in force:** rerun rows S and V of the setup audit (shipinetics:setup): env scrub on, deny rules matching the vault the project uses, the CI evidence job in every repo that opens PRs. Report anything partial at the top of the sweep report, with what it leaves unprotected.
- **Verification map drift:** run shipinetics:verification-map `maintain` (weekly sweeps). Put its outcome in the report: clean, changed (what) or blocked (what's needed).
- **Full security audit:** run `shipinetics-config due security-audit`. If it says due, run the full audit as shipinetics:review describes ("Full security audit"), record it in `docs/security/audits.md`, and put the counts by severity in the sweep report. The user agreed to this when they chose the cadence.
- **Companions missing:** run `shipinetics-companions missing` and list each missing companion in the report, with why Shipinetics uses it.
- **Companions out of date:** run `skills-outdated` for the skills (read-only; never `npx skills check`, which can update and remove skills), and compare `claude plugin list` with each companion plugin's marketplace. If the sandbox blocks the network, give the user the command instead. Report what has an update. Don't update anything yourself: updates change what runs with the user's permissions, so the install gate asks the user. For each update the user wants, scan the new version first (shipinetics:security-scans). After the user updates, read the companion's new SKILL.md and check what Shipinetics relies on still holds (README, "What Shipinetics needs from each companion"). If it doesn't, queue a task to update Shipinetics.
- **Verify time:** `shipinetics-verify times 7`. If the quick tier regularly takes more than a minute, find which step is slow and scope it better. If the complete tier keeps failing at the done gate on things the quick tier could have caught, move a scoped version of that check into `--quick`.

## Act

- **Small, safe fixes** (stale doc lines, a missing queue task, a leftover debug line): fix them now, with `bin/verify` passing, in a commit with the trailer `Worksheet: <sweep worksheet name>`.
- **Anything larger:** add a task to the queue with the evidence (commits, files).
- **Recurring problems:** propose a lint rule (shipinetics:lint-rule) or a convention.
- **Architecture:** if the same complexity hot spots show up sweep after sweep, suggest the user run `/improve-codebase-architecture` (Matt Pocock's skill, interactive) on them, and add what they choose to the queue. Its report opens with `open`, which some sandboxes block: give the user the path instead.

## Report

Write `docs/sweeps/YYYY-MM-DD.md`:

```
# Sweep YYYY-MM-DD
> Summary: <range, number of commits, top findings in one line>
> Range: <since>..<head> | Worksheets covered: <list>

## Findings
| # | Kind | Evidence (commits, files) | Action (fixed in <sha> / queued T-NNN / proposed rule) |
```

Then tag the head commit you swept: `git tag sweep/YYYY-MM-DD`. The next sweep starts there.
