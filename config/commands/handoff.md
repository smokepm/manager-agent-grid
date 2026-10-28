---
description: Hand your finished work to the agent-grid manager for testing
---
<!-- installed by agent-grid -->
Wrap up and hand off to the manager.

1. Make sure every process your code runs has an up-to-date workflow in `.agent-grid/workflows/<name>/` (`run.sh` and `WORKFLOW.md` with a "Correct means" section), and that each `run.sh` works from the folder root.
2. If `.agent-grid/checks.toml` exists, run each workflow's `run.sh`, then `agent-check`, from the folder root, and fix anything that fails. The manager runs the same checks first, so a failure there costs a whole round.
3. Give a short summary: what you changed, how you checked it, and anything you're unsure of.
4. End your reply with this line exactly:

HANDOFF: ready for the manager
