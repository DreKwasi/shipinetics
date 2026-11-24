# Plain language for PR descriptions

ASD-STE100 (Simplified Technical English) is a controlled-language standard for technical
writing that is read fast, under load, by someone who did not write the thing being
described. That describes a PR description. Use it as a baseline, not a compliance
target: the goal is prose a reviewer parses correctly on the first pass.

The rules below are the whole of it. The [exemptions](#what-is-exempt) matter as much as
the rules, because a rule applied to an identifier does damage.

## The rules

**Use the active voice.** Name the actor. "The parser rejects unknown keys", not
"unknown keys are rejected". Passive voice hides who does the work, which is exactly
what a reviewer of a permissions or validation change needs to know.

**One topic per sentence.** If a sentence carries a fact and its consequence and a
caveat, it needs to be two or three sentences.

**Keep sentences under about 25 words.** Long sentences in a PR description almost
always turn out to be two facts joined by a comma.

**Use simple tenses.** Prefer "the gate rejected the request" over "the gate had been
rejecting requests". Simple past, simple present, simple future cover nearly everything.
Keep the present perfect only when it carries something the simple past cannot. "The
job has completed" says the output is ready now. "The request may have failed" keeps a
doubt.

**Keep the articles and the connecting words.** "Fix for case where config is nil" reads
as a telegram. "This fixes the case where the config is nil" costs three words and one
less reparse. Keep "that" and "which" rather than dropping them.

**Use one term per concept, for the whole description.** If you call it a tenant in the
first paragraph, it is a tenant in the last. Switching between tenant, organization, and
account makes a reviewer wonder whether you mean three things. The same applies in
reverse: do not use one word for two concepts. Also keep each word in one part of
speech: "apply oil to the valve", not "oil the valve".

**Do not stack more than three nouns.** "Consumer retry backoff configuration override"
forces the reader to guess the bracketing. Break it up with prepositions: "the override
for the retry backoff on the consumer".

**Use a vertical list when there is more than one condition or step.** Prose that
carries three conditions in one paragraph hides at least one of them.

**Prefer the specific word.** "Handles", "supports", "manages", and "processes" are
placeholders for a verb you have not chosen yet. "Validates", "retries", "rejects",
"caches" tell the reviewer what the code does.

**Use the verb, not a noun made from it.** "Analyze the log", not "perform an analysis
of the log". "The hook blocks the push", not "the hook provides blocking of the push".
The noun form is longer, and it hides who acts.

**Use one-word verbs, not phrasal verbs.** "Start the job", not "spin up the job".
"Contact", not "reach out to". "Read", not "dive into". "Begin", not "kick off". A
two-word verb has meanings that its parts do not predict.

**Do not use semicolons.** Make two sentences. An em dash that joins two ideas is
usually the same problem: split the sentence.

**Keep paragraphs to about six sentences.** Past that, split them or make them a list.

**Keep the strength of each claim when you rewrite.** A hedge ("may", "could", "is
likely to") is part of the content. "The request may have failed" does not become "the
request failed". Do not add a cause, a frequency or a mechanism that the source does not
state. If a shorter sentence loses a condition, a scope or a number, keep the longer one.

## Text that agents and programs read

Apply the rules above as hard rules, not as a baseline, to text that a model or a
program reads with no person to resolve a doubt. That text includes skill text, agent
prompts, tool descriptions, hook and error messages, and instructions from one agent to
another. For this text, also use one word for one action everywhere. Always "check", for
example, never "check", "verify" and "confirm" for the same action.

## What is exempt

STE's approved-word list is for controlled documentation, not code review. These are
technical names and stay exactly as they are:

- Code identifiers, type names, field names, and file paths: `FactoryConfig`,
  `spawn_server_impl`, `logic/factories.go`.
- Command lines and their flags, verbatim.
- Established repository and domain jargon: merge queue, feature flag, migration,
  presubmit, one-way door.
- Product and service names.

Do not paraphrase an identifier into prose to satisfy a word rule. `nil` is `nil`, not
"an empty value".

## Two rewrites

**Passive and vague:**

> The cache layer was updated so that stale entries can be handled appropriately.

**Active and specific:**

> Each cache entry now records the version of the pricing table it was built from. The
> lookup compares that version against the current one, and rebuilds the entry when they
> differ.

---

**Intent stated as result:**

> Added tests to make sure the migration is safe to roll back.

**Result stated as result:**

> `migrate down` drops the index and leaves no other residue. The integration test
> asserts this against a local PostgreSQL instance.

## Words that add nothing

Cut these unless they carry weight: comprehensive, robust, cleanly, properly, simply,
just, basically, essentially, in order to, it should be noted that, a number of.

Cut the adjectives that claim quality instead of showing it: seamless, powerful,
cutting-edge, effortless, blazing-fast. Give the measurement that earns the claim, or
delete the word.

"Simply" and "just" are worth singling out. They tell a reviewer that the thing they are
about to read is easy, which is either redundant or wrong, and occasionally insulting.
