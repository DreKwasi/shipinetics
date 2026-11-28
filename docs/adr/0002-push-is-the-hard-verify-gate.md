# The push is the hard verify gate; the check after a commit only reports

The complete verify blocks a push (the pre-push hook) and a pull request (the PR gate), and nothing earlier blocks on a test. The quick verify that runs after each commit only tells the agent the result. We chose this because the task loop needs commits with failing tests (the code is committed before test-writer updates the tests of changed behaviour), and because the Stop hook that ran verify each time the agent stopped (removed in 0.8.0) trapped the agent in loops on flaky tests and cost minutes on plain questions. A push is the last moment before code reaches other people, so a complete pass must be true there.

## Considered options

- **Verify in a pre-commit hook that blocks.** It stops the commit that test-writer needs, makes commits slow, and teaches people to use `--no-verify`.
- **Verify each time the agent stops** (Shipinetics up to 0.7). Removed for the loops and the cost.
