---
name: lint-rule
description: Turn a recurring problem or a review convention into a lint rule that fixes code automatically, with an LLM fallback when an autofix isn't feasible. Use when the same mistake shows up twice, when a reviewer cites a convention marked "enforced: review", or when the user asks for a new lint rule.
argument-hint: "<problem or convention ID>"
---

# Encode it in a linter

> Paths below are Shipinetics's defaults. A project can map them elsewhere in `.shipinetics/config`: run `shipinetics-config` to see this project's actual paths and commands, and use those.
>
> Text for people (docs, worksheets, reports, PR bodies, replies): write it in ASD-STE100. Where the text describes structure or flow (a call path, a data flow, states or steps), show it on a Whiteboard. In a committed file, also put a Mermaid diagram and a link to the Whiteboard, because GitHub and other people cannot open your Whiteboard. Without Whiteboard, use Mermaid only. shipinetics:explain has the rules.

Every problem a linter catches is one reviewers and agents never have to think about again. The goal isn't to flag problems, it's to end up with clean code automatically.

Problem: `$ARGUMENTS`

## Decide the cheapest way to enforce it

Go down this list and stop at the first that works:

1. **An existing rule** in the linter the project already uses, maybe with config. Search the linter's rule list and plugins before writing anything.
2. **A custom rule with an autofix** in the project's linter (ESLint custom rule, Ruff/Flake8 plugin, Semgrep rule with `fix:`, golangci custom analyzer, a codemod with ast-grep). Put custom rules in `tools/lint-rules/` (or where the project keeps them).
3. **A custom check with no safe autofix.** The pre-commit hook (`bin/lint-fix`) sends files that still fail to `bin/llm-fix`, which asks a cheaper model to fix just those problems in just that file. Write the rule's error message so a model can act on it: say what's wrong, where, and what the fix looks like.
4. **Not mechanically checkable.** Keep it in `docs/conventions.md` as `Enforced: review`, with a clear example.

## Writing the rule

- **Test it** like code: a fixture that should fail, one that should pass, and for autofix rules, the expected output after fixing. Run it against the whole repo and look at every hit.
- **Fix existing violations** in the same change, using the autofix. If there are too many, fix them in a separate commit first.
- **Error messages teach.** `"Use money.fromCents() instead of dividing by 100 (C-014). Floats lose cents."` beats `"invalid division"`.
- **No disable comments** to get existing code through. If code legitimately needs an exception, the rule is wrong.
- Keep the rule fast. It runs on every commit.

## Wire it in

1. Make sure `bin/lint-fix` runs it (the `fix` and `check` functions at the top).
2. Update `docs/conventions.md`: change the convention's `Enforced:` line to `lint <rule-name>`, or add a new convention entry.
3. Commit with the trailer `Worksheet: <name>`. Note in the worksheet which recurring problem this rule ends.

## The LLM fallback

`bin/llm-fix <file> "<lint output>"` runs a cheaper Claude model (Sonnet through `claude -p` by default; `SHIPINETICS_FIX_MODEL` sets another) restricted to reading and editing that one file. If it touches anything else, the change is rolled back. `bin/lint-fix` re-checks afterwards, so a bad LLM fix still fails the commit. Turn it off for a commit with `SHIPINETICS_LLM_FIX=0`.
