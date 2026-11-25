# Writing a PR description

> Adapted from `write-pr-description` and its `review-guide.md` in [warpdotdev/common-skills](https://github.com/warpdotdev/common-skills) (MIT License, Copyright (c) 2026 Denver Technologies, Inc.). See NOTICE.

A PR description gives the reviewer what the diff can't. The diff shows what changed. The description says why it changed, what it affects, which decisions you made, and where you want attention. When a rule here conflicts with what a reviewer needs, do what the reviewer needs.

`evidence pr-body` writes the `## Evidence` section (shipinetics:evidence). The review adds `## Merge risk` (shipinetics:review). This guide covers the rest: the summary, the repo's template, and the review guide.

## 1. Collect the facts

- **The worksheet first.** Its Decisions, Claims, Reviews and Open questions sections hold most of what the reviewer needs. The Log is history: don't copy it (see "Narrating the branch's history" below).
- **Commit bodies next:** `git log <base>..HEAD`. They carry the why.
- **Check each claim that you carry over.** A commit message that says "matches the pattern in this file" makes a claim about code, and it is often wrong. Check it by looking, not by reasoning:
  - Read what the change deletes. For a fix, the defect is usually in the removed code.
  - Ask the system what a thing means: the role's permissions, the API schema, the parser.
  - Grep a flag in the environment and config files before you say that it is on or off.
  - Open the file that a comment points to, and confirm that it says what the comment claims.

## 2. Follow the repo's PR template

Look for a template each time: `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE/*.md` (pick the one that matches the change), `docs/pull_request_template.md`, or `pull_request_template.md` at the root. **The template's own instructions win over this guide.**

- Keep its headings, their words and their order. Reviewers and tools look for them.
- Answer each section in your own words. Don't copy the template's questions, links or examples.
- If a section doesn't apply, say so in a clause that shows you considered it: "No new tables." Don't delete it or leave it empty.
- Tick a box only when its statement is true. Otherwise leave it empty, with a short reason on the same line.
- Keep machine-read content: changelog markers, issue keys (`Fixes #12`), media markers. Check that a marker isn't inside an HTML comment that the parser removes.
- Put `## Evidence` and `## Merge risk` after the template's sections, with those exact headings: CI and the PR gate look for `## Evidence`. If the template has a testing section, write one line there that points to the Evidence section.

With no template, use this order. On a small change, drop each heading that would hold one line:

1. The opening paragraph, with no heading.
2. `## Review guide`, only when section 4 calls for one.
3. `## What changed`
4. `## Evidence`, then `## Merge risk`.

## 3. Write the body

**Open with one to three sentences:** what the change does and why. A reviewer who reads only this paragraph must know whether the PR is theirs.

Then:

- **Name each change in behaviour,** also the side effects. These break other people's work. For a permission change, give the direction: what is now allowed that was refused, and what is now refused.
- **Record each decision with the alternative that lost,** and why it lost. This is the most valuable content, and the diff can't show it. If there was no real alternative, state the decision. Don't invent one.
- **Say where you are not sure.** If you inferred an intent that nobody wrote down, a human must check that inference.
- **Give the blast radius** when it is wide (section 4).
- **Explain the mechanism only when the code doesn't show it:** a new abstraction, a rule that holds across files, an unusual control flow. A renamed field needs no explanation.
- **Link the issue or the spec once.** Never invent a ticket ID. A wrong link costs more than no link.

**What you verified.** The Evidence section shows what ran. In the summary, say once what you did not verify, with the reason, and the check that you ask the reviewer or CI to make. Use the shape that is true. More than one can apply:

- Nothing ran: say so, and name the command to run.
- CI produces the result, because the check needs an environment you must not use: name the job, and say what you expect it to show, as an expectation, not as a result.
- Tests are added but no run is recorded: say that they didn't run.
- You couldn't run it (no device, no access): say so, and ask the reviewer for that check. If you could have run it, run it.
- Someone else recorded the result: name them, or leave it out.

Never write intent as a result.

## 4. Add a review guide only when it helps

Add one if one of these is true:

- **The reading order isn't obvious:** file B makes sense only after file A.
- **You want attention on a specific place:** something you aren't sure of, a decision that could go either way, or a place where a mistake costs a lot.
- **The change can break things far beyond the files it touches.**

**Wide blast radius,** worth a guide even for a one-line diff: permissions, authorization, tenancy, network and firewall rules, a newly exposed endpoint, schema migrations, stored data formats, retention and deletion, public API contracts, feature-flag defaults, shared components, and any contract that other code depends on.

**Narrow blast radius,** even when users see it: a small UI change, a few new or moved routes, copy changes, a new endpoint or component that nothing uses yet, test-only changes. The test is what else can break, not how many people see it.

**Focus areas.** Each one names a file, a symbol or a decision. Use this shape: the location, the decision, the reason, the question.

> `billing/invoice.go` treats a zero-amount line as a deletion, not a no-op, so the line disappears from the invoice. I think this is correct, because the upstream system sends zero only for removed items. Please check this.

Good focus areas: where you aren't sure; a value or name that looks wrong (say whether it is deliberate, and ask); what a security change now permits, and who is now inside the boundary; a decision where a reasonable engineer could choose the other way; a change that is expensive to reverse when you aren't sure of it.

**Reading order,** only for about ten or more files that aren't generated. Order by dependency: the new contract or mechanism, then its first real user, then the wiring, then the mechanical rest. Give one clause of reason for each step. Use three to six steps. Name what the reviewer can skim, and why: "`types.gen.go` is generated from `openapi.yaml`. Review the YAML."

On a small PR, the guide is one or two sentences in the opening paragraph, not a section. Write for a competent engineer: point to the code and the question. Never tell the reviewer how to review ("please check the error handling").

## 5. Cut

Find the decision that each paragraph helps the reviewer make. If you can't name one, delete the paragraph. The usual cuts:

- What the diff shows at a glance: "the field was renamed", one bullet for each changed file. Exception: a thing that looks wrong but is deliberate, such as a name that doesn't match what it binds to.
- A paraphrase of comments that the diff adds.
- A list of the tests you added. Say what isn't covered.
- How a standard tool works. Explain this change, not the reviewer's tools.
- A fact that you state twice.
- Sentences that point to another part of the description, or that talk about the description.
- Commit trailers.

Approximate length: a test, config or mechanical change with no behaviour change needs a short paragraph. A focused fix or feature needs about 400 to 500 words. A new mechanism needs fewer than 1,000. These are guides, not limits. Never cut a decision, a rejected alternative, an open question or the blast radius to fit one.

## 6. Check before you open the PR

- The first paragraph tells a reviewer whether the PR is theirs.
- Each claim about testing describes something that ran, or says that it didn't.
- You checked each fact that you carried over from a commit message or the worksheet.
- The cut didn't remove a decision, a rejected alternative or an open question.
- The description matches the branch as it is now.
- The review guide, if there is one, is near the top.

## Mistakes to avoid

- **Narrating the branch's history.** "This PR first added unit tests, which were removed after review" describes a change that the reviewer can't see. The reviewer sees one state against the base. Describe that state, and keep the reason: "There are no unit tests here, because a test at this layer would only repeat the match arms." Never copy the worksheet Log into the PR.
- **Restating the diff,** file by file.
- **Claims that you didn't check,** about tests or about how the code works. A confident wrong claim about a mechanism is the most dangerous, because a reviewer is less likely to check it.
- **Grading your own work:** "comprehensive", "robust", "clean".
- **A stale description.** After a rework, rewrite the summary for the branch as it is now, not only the Evidence section. Don't add a revision log at the end.
