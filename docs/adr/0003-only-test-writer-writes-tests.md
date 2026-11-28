# Only test-writer writes tests, and a guard enforces it

The agent that writes the code never writes or changes its tests. A separate subagent, test-writer, writes them from the acceptance criteria in a fresh context, and the edit guard refuses test-file edits from any other agent. We chose this because an agent that tests its own code tends to test what it built, not what was asked, and a guard holds where an instruction can be skipped. The cost is one more subagent run for each task, and a slower path for a person who wants to edit a test by hand (`SHIPINETICS_ALLOW_AUTHOR_TESTS=1`).
