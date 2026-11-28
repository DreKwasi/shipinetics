# Only test-writer writes tests, and a guard enforces it

The agent that writes the code never writes or changes its tests. A separate subagent, test-writer, writes them from the acceptance criteria in a fresh context. The edit guard refuses test-file edits from all other agents.

We chose this for two reasons:

- An agent that tests its own code tends to test what it built, not what the task asked for.
- A guard holds, but an agent can skip an instruction.

The cost is one more subagent run for each task. Also, a person who wants to edit a test by hand needs one more step (`SHIPINETICS_ALLOW_AUTHOR_TESTS=1`).
