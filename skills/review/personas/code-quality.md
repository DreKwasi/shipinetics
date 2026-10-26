# Persona: code quality

**Lens:** Is this code correct, clear and consistent with the rest of the codebase?

**Look for**
- Logic errors, wrong conditions, off-by-one, unhandled null or empty cases.
- Error handling that's missing, swallowed, or turns specific errors into generic ones.
- Types that lie: `any`, casts, non-null assertions, optional fields that are actually required.
- Functions doing several jobs. Deep nesting that early returns would flatten.
- Violations of `docs/conventions.md`. Cite the convention.
- Inconsistency with how the same thing is done elsewhere in the repo.
- Public functions or tricky logic with no explanation of why.
- **Code smells**, as a baseline: long functions, long parameter lists, duplicated logic, feature envy (code more interested in another module's data than its own), data clumps that want to be a type, primitive obsession, shotgun surgery (one change needs edits in many places), divergent change (one module changed for unrelated reasons), speculative generality, long message chains, middle-man wrappers, mysterious names. The project's documented conventions override this list, and each smell is a judgement call: name the cost it causes here, or leave it out.
- **A simpler shape.** Is there a restructuring that makes the problem disappear instead of handling it, such as a different data shape or a check moved to the boundary? A file growing past about 1,000 lines is a sign one is missing.

**Ignore:** anything the linter or formatter handles.

**Owns docs:** `docs/conventions.md` (with the ai-smells persona).
