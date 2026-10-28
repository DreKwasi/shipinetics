---
name: review
description: Cross-agent review at a checkpoint (research, plan, implementation, wrap-up), with a fresh-context Opus reviewer, specialist reviewers and persona lenses. Use when you finish research, a plan or an implementation, before calling a task done, or when the user asks for a review.
argument-hint: "[research|plan|impl|wrapup|docs] [persona...]"
---

# Cross-agent review

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.
>
> Text for people (docs, worksheets, reports, PR bodies, replies): write it in ASD-STE100. Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

The author never reviews its own work. A reviewer in a fresh context, with no stake in the work, catches what self-review misses.

Stage and personas from the arguments: `$ARGUMENTS`. If no stage is given, infer it from where you are in the workflow.

## When to review

| Checkpoint | What's reviewed | Required when |
|---|---|---|
| **research** | The worksheet's Research section and claims table | The task touches a system you haven't read before, or the research drives a risky plan |
| **plan** | The spec or plan with acceptance criteria | Anything bigger than a small change (see shipinetics:workflow for sizes) |
| **impl** | The diff against the base | Always, before the task is done |
| **wrapup** | The whole task: diff, docs, worksheet, queue | End of a task over size S |
| **docs** | A system doc, spec or explainer whose factual content changed | Whenever factual claims in docs change, especially external facts |
| **merge-risk** | The whole PR, after its evidence is recorded | Every PR, just before it opens or is marked ready |

Research and docs reviews return a **claims table** instead of findings: every claim with a verdict (verified, incorrect, unresolved), the evidence the reviewer opened (`file:line`, or a primary source URL with the date checked), and the correction. Apply corrections, recheck neighbouring sentences whose meaning changed, and keep unresolved claims visibly marked.

## How to run one

1. **Write down what's being reviewed** in the worksheet: stage, base ref or file, acceptance criteria.
2. **Claude reviewer.** Spawn the `shipinetics:reviewer` subagent. It runs on Opus at high effort (its frontmatter). Don't pass a model or an effort. Give it the stage, the base ref or file, the acceptance criteria, and a persona if one applies.
3. **Pick personas and specialist reviewers** (below). Run each through the reviewer in step 2, or the specialist agent named in the table. Don't run every one every time. Run them in parallel where you can.
4. **Merge, then filter.** When several reviewers ran, put their findings in one table and mark where they agree: a finding two reviewers raised independently goes first. Before acting, filter each finding the way a lead would. A finding must name a concrete input or state that goes wrong: "this could fail if" without one is hypothetical, and you note it rather than fix it. "I'd do it differently" isn't a finding unless the other way removes a defect. Minor findings never block. Record filtered findings as **disagree** with the reason.
5. **Respond to every finding.** For each one, in the worksheet's Reviews section: **fixed** (with the commit or change), **disagree** (with a reason a human would accept), or **deferred** (with the task ID you added to the queue). Silence isn't an option.
6. **Re-review** only if your fixes were substantial or a reviewer said `blocked`. Stop after two rounds and flag the disagreement for a human.

### Independent re-check at wrap-up

The author's screenshots show what the author saw. For tasks M and up, and any change that touches UI, the wrap-up reviewer also drives the change itself. Tell `shipinetics:reviewer` to re-check: it launches its own instance from `docs/verification/README.md` (or reuses the running one after the doctor check passes; with `launch = user` it always reuses the user's instance), drives the main feature the task touched through every entry point its feature file lists, and reports PASS, ISSUES or BLOCKED per feature, with its own artifacts under `$TMPDIR`. It runs once, on the final code, after review fixes. Later commits that change only docs, tests or records keep the verdict. Any other change needs a new re-check. Record the verdict and the commit it ran at in the worksheet's Reviews table.

## Choosing personas

Persona files live in `${CLAUDE_SKILL_DIR}/personas/`. A project can add its own or override one in `docs/review/personas/<name>.md` (the project version wins).

| Persona or reviewer | Run it when | How |
|---|---|---|
| `test-integrity` | Any test file changed. Always at impl stage | `shipinetics:reviewer` with this persona |
| `ai-smells` | Every impl review | `shipinetics:reviewer` with this persona |
| **security** | Auth, input handling, file or network access, secrets or config, permissions, dependencies, anything reachable by untrusted users | `shipinetics:security-reviewer`, which uses Cloudflare's `security-audit` skill in guidance mode plus the security persona. |
| **frontend** | Any change to UI: components, styles, routes, copy, layout | `shipinetics:ui-reviewer`, which checks conformance to DESIGN.md (`design-check` plus a manual pass), then runs impeccable's `critique` and `audit` against real screenshots. Its "Design-system gaps" go to the worksheet's design-system change requests |
| `performance` | Hot paths, loops over data, queries, rendering, startup, bundle size | `shipinetics:reviewer` with this persona |
| `maintainability` | New modules, new abstractions, large diffs, changes to shared code | `shipinetics:reviewer` with this persona |
| `code-quality` | Medium and larger diffs | `shipinetics:reviewer` with this persona |
| domain persona (e.g. `domain-finance`) | Anything touching that domain's rules. The project defines these from `domain-expert-template.md` | `shipinetics:reviewer` with this persona |

The security and frontend reviewers depend on skills you install separately: `security-audit` (from `cloudflare/security-audit-skill`) and `impeccable` (the plugin from the `pbakaus/impeccable` marketplace). If one is missing, its reviewer says so and falls back to the persona file. `/shipinetics:setup` checks for both.

### Full security audit

`security-audit` also has a full six-phase audit mode that writes report artifacts outside the repo. It's expensive and thorough. Run it when the user asks, before a major release, or when the user's cadence says it's due, never automatically inside a task.

- **The cadence is the user's choice:** `security_audit_every` in `.shipinetics/config` (`off`, `weekly`, `monthly`, `quarterly` or `<days>d`; setup asks). `shipinetics-config due security-audit` says whether one is due. The weekly sweep checks it.
- **To run one:** spawn `shipinetics:security-reviewer` and tell it "full audit" with an output directory outside the repo (security-audit's default, `~/security-audit-skill/<repo>/run-<N>`).
- **Record it:** when it finishes, append one line to `docs/security/audits.md` (create it with a `# Security audits` heading) and commit it: `- YYYY-MM-DD <short commit> <profile>: <counts by severity> (<complete or incomplete>), report in <output directory>`. Only the counts go in the repo. The findings stay in the output directory, and each confirmed critical or high one becomes a queue task.

A release security pass also includes `scan-skills` and, with the user's approval, a Strix run against staging (shipinetics:security-scans).

## Merge risk: how much of the human's attention a PR needs

Review time is the bottleneck. A merge-risk grade tells the human where to spend it. Every PR gets one, from an independent reviewer, never from the author:

1. After evidence is recorded and `evidence check` passes, spawn `shipinetics:reviewer` with stage `merge-risk`, the base ref and the worksheet. It loads the `merge-risk` skill (install it with `npx skills add warpdotdev/common-skills --skill merge-risk`), which grades alignment, impact, verification, rollback cost and error detection, and rolls them up into low, medium or high.
2. Put its output in the PR body under a `## Merge risk` heading, after the Evidence section. Put the overall grade in the Whiteboard's top callout and in the worksheet's Metrics.
3. If a gap it lists is cheap to close (missing before-and-after screenshots, an unlogged error path, an undocumented assumption), close it and grade again before opening the PR.

What the grade means for the human:

| Grade | Suggested review |
|---|---|
| low | Check the evidence and the grade's notes, skim the diff, merge |
| medium | Read the Whiteboard and the files the grade flags |
| high | Full review: Whiteboard walkthrough, every flagged file, and the security reviewer's report if one ran |

The grade informs the human's decision, it never replaces it. Nothing merges automatically unless the user has set that up explicitly. To check the grades are trustworthy, the feedback ingest compares each grade with the corrections the human actually needed.

## Whiteboard for the human

Agent reviewers check the work. The human still has to understand it. For tasks M and up, author a Whiteboard of the change if the Whiteboard MCP tools (from dev.fast) are available:

1. Call `session_capabilities`, then `session_get_instructions` (default topic), and follow those instructions exactly. They change between versions, so don't work from memory.
2. Target the task's change: the worktree against the base branch for uncommitted work, or the commit range for committed work.
3. Put the merge-risk grade, the agent review verdicts and any open findings in a callout near the top, so the human sees what's already been checked. Write all the Whiteboard's text in ASD-STE100 (shipinetics:explain).
4. Add an Evidence section: upload the key screenshots from `docs/evidence/<worksheet>/` with `session_upload` and show them as image components next to the criteria they prove. Link the recording.
5. Link the Whiteboard from the worksheet's Reviews section.

If Whiteboard isn't available, write an HTML explainer of the change instead (shipinetics:explain).

## Personas own docs

Each persona file has an **Owns docs** list. When a persona reviews a change that touches its area, it also checks those docs are still accurate and says which ones need updates. The author updates them in the same change. This is how docs stay current without a separate docs pass.

## Things reviewers get wrong

- Approving because tests pass. Tests passing proves nothing if the tests were changed. That's why `test-integrity` always runs.
- Reviewing the summary instead of the diff. The reviewer reads code, not your description of it.
- Drowning real issues in nitpicks. Severity matters. Minor findings never block.
