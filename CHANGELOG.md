# Changelog

## 0.14.1 (2026-10-02)

- Ready to publish: examples use made-up folders and figures, and the levy software isn't named. Set `LEVY_SOFTWARE` in your config to name yours, and setup is told to look for its certified rolls and exports.
- `.gitignore` keeps spreadsheets, CSVs, PDFs, Word files, and `.agent-grid/` folders out of the repo.

## 0.14.0 (2026-10-02)

Clearer status, enforced ownership of your checks, and a stronger answer key.

What you see:
- The manager pane shows each agent's status in plain words with its last result, and only lists recent activity for the folders on screen (closed folders stay in the log).
- Setup sessions show **[setting up checks]**, then **[checks ready: your turn]** when the summary is waiting for you. Before, a folder being set up looked idle.
- A pass says what it covered: "passed: ran 1 workflow(s) in a copy; your checks passed; backtest passed; ... the manager found nothing", or what was missing (no backtest, no checks.toml).
- A read-only review is logged as one ("read-only review ... nothing was run"), not as "passed". When only data or output files changed, the log says "nothing to review" instead of running a review of file-size lines.
- An analyst that stops without changing anything after being asked for a workflow is handed to you right away with its reply, instead of being asked a second time with the same message.

Your checks are enforced, not just requested:
- A PreToolUse hook blocks analyst edits to `checks.toml`, `backtest/`, and `review.md`, and shell commands that would change them. Reading them stays allowed. Change detection at each test stays as the backup.
- Analysts are told to stop and explain when a check looks wrong, rather than change the code to fit it or special-case parcels.
- Setup sessions and the manager run with Claude's auto memory off (`CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`), so their notes can't load into analyst sessions. `ANALYST_AUTO_MEMORY=0` turns it off for analysts too.
- Setup no longer takes rules or numbers from memory notes or earlier sessions, searches only the folder and its parent, and asks you for anything it can't find there.

A stronger answer key (levy-check):
- `[max_rates]`: each rate class's max rate from the RMA, stated or computed from base rate, base year, escalator, and rounding. Every levy must be at most units × max rate, so a wrong escalator can't hide in the roll's own columns. The backtest checks last year's roll against last year's max, and points out certified parcels that were over it.
- `[backtest.known_differences]`: certified parcels the code shouldn't reproduce, one line each with the reason.
- `[totals]`: expected totals by district, zone, or fund.
- `unique_by`: uniqueness on several columns (e.g. APN + account) where a parcel can appear more than once.
- `levy-check selftest`: plants errors in copies of the rolls and reports which checks catch each one. Setup runs it and summarizes the gaps.
- `spawn --spot [DIR]`: your hand-calculated parcels, kept in `~/.config/agent-grid/spot/` where analysts can't read them. The manager compares the roll with them on every test, and a mismatch comes to you, not the analyst.

Install: re-run `install.sh` to add the PreToolUse hook. `spawn --doctor` checks for it.

## 0.13.2 (2026-10-02)

- Fixed: a folder's first review could blame the analyst for your own recent edits (files changed in the last two hours, or any uncommitted change in git), sending it back for "code changes" it never made. Now the first prompt of a managed session sets the starting point, and only changes after it count as the analyst's.
- The feed and log say why a turn was sent back, including which code files changed.

## 0.13.1 (2026-10-02)

- Setup asks you fewer permission questions: it's told how levy-check works (so it doesn't read the script) and to run one command at a time, which pre-approved commands cover. cat, wc, and file are pre-approved too.
- `levy-check --help` (and `init --help`) shows help instead of running the command.

## 0.13.0 (2026-10-02)

- `spawn --setup [DIR]`: a setup Claude finds the roll, last year's certified roll, and last year's inputs, writes `checks.toml`, copies the backtest files in, runs `levy-check`, and summarizes where every number came from for you to confirm. It builds checks from the data and the RMA only, never from the levy code.
- At launch, `spawn` offers setup for any managed folder without checks ([Y/n/never]); setup runs first in that pane, then the analyst.
- The backtest uses the folder's workflow automatically (name one only if there are several) and starts once the analyst writes it. A blank `backtest.expected` means no backtest.
- Analysts are told to write the roll at the path and columns `checks.toml` names.

## 0.12.1 (2026-10-02)

- The installer adds gawk on Fedora, whose minimal WSL image doesn't include awk.
- Doctor: checks for awk directly, and compares the tmux version without it, so a missing awk no longer shows up as "tmux is too old."

## 0.12.0 (2026-10-02)

Simpler: one straight line from an analyst finishing to the verdict.

- Removed background testing. The analyst now waits while its manager tests, and the verdict goes straight back. This removes pasting findings into panes, holding findings for busy analysts, and stopping outdated tests. `TEST_MODE` is gone.
- Removed the outside-path scan and the "Outside paths" section of WORKFLOW.md. Containment already makes everything outside the copy read-only on the Linux side; the check for the folder's own full path stays.
- A hand edit made while a test runs isn't pushed until a later test covers it.
- Waiting for another folder's Excel test is now its own status, [manager queued for Excel], and counts as testing in the status bar.

## 0.11.0 (2026-10-02)

- Round memory: each review is still a fresh Claude, but it now gets a written record of earlier rounds (the findings and the analyst's reply). It verifies each earlier finding is fixed, and raises a disputed one again only with new evidence. A pass clears the record. The reply comes from the Stop hook, or the transcript if the hook doesn't provide it.
- `spawn --watch [DIR]` (and `Ctrl+b W`): follow a review live, with the hook's steps, the manager's reasoning, each command it runs, and the verdict. It keeps following each new review for that folder.
- The manager now streams its work (`--output-format stream-json`). Its final answer is read from the stream; plain-text output still works. A stream that ends without an answer counts as unfinished, never as a pass.
- Clearer notes when the manager times out, errors, or stops without a verdict.

## 0.10.0 (2026-10-02)

- Your checks replace the answer file: `levy-check init` writes `.agent-grid/checks.toml`, with rules every roll must meet (unique APNs, no negatives or fractional cents, levy within max tax, max tax = units x rate, total ties to the levy requirement, every county-export parcel on the roll) and a backtest: last year's inputs through the new code must reproduce last year's certified roll, parcel by parcel, to the cent.
- On every test, after the baseline run: your rules on this year's output, then the backtest in its own copy. Failures go straight back to the analyst with the failing parcels, without a manager review. An unusable `checks.toml` comes to you.
- The manager uses `levy-check` on its own altered inputs, and aims at what your checks can't see (anything new this year).
- Leftover rolls are removed from each copy before running, so a workflow that stops writing its roll can't pass on a stale one.
- `checks.toml`, `.agent-grid/backtest/`, and `review.md` are yours: changes between tests are reported, and they're never auto-pushed. The answer file is gone.
- Doctor checks that levy-check has Python 3.11+ and openpyxl.

## 0.9.0 (2026-10-02)

- One answer file replaces the reference system: `.agent-grid/answer.md` (or `.txt`, `.csv`, `.xlsx`) holds your known-good results. The manager gets it with every test and checks every figure and rule in it against the outputs. It outranks anything the analyst wrote.
- If the answer file changes or disappears between tests, the result says so and you're notified. Changing it triggers a new test. It's never auto-pushed.
- Removed: `.agent-grid/truth/`, reference approvals (`spawn --approve`, `--restore`, the launch-time prompt), reproduction scripts, regression checks, `REQUIRE_REFERENCE`, `FINDINGS_MAX`, and `spawn --test-manager`.
- Kept from 0.8.0: background testing, containment, the Excel lock, data expiry, `spawn --test`, `spawn --clean`.

## 0.8.0 (2026-10-02)

- Reference you approve: `.agent-grid/truth/` (known-good results, rate tables, the RMA), `review.md`, and regression checks are yours. `spawn` asks you to approve new or changed ones at launch; any unapproved change stops testing. `spawn --approve`, `spawn --restore`. `REQUIRE_REFERENCE=1` refuses to test without a reference.
- Findings need proof: the manager writes a script per problem (exit 3 while present), the hook reruns each in a fresh copy and drops anything that doesn't reproduce. Confirmed scripts become regression checks in `.agent-grid/regressions/`, run first on every later test.
- Background testing (`TEST_MODE=background`, default): the analyst is free while the manager tests. Findings are pasted in when the analyst is idle, or handed over when its turn ends. A newer change stops the stale test. Only tested, unchanged versions are pushed.
- Containment: tests run in bubblewrap, so the real folder, its neighbors, and Windows drives are read-only. Absolute paths outside the folder must be declared under "Outside paths". The installer adds bubblewrap; `spawn --doctor` checks it, including Windows programs under WSL.
- Excel tests take turns machine-wide ([manager queued for Excel]).
- Client data: failed copies expire after `WORKFLOW_KEEP_DAYS` (3), reviews after `REVIEW_KEEP_DAYS` (30), copies are private to your user, `spawn --clean` deletes them. New reference and regression files are never auto-pushed.
- `spawn --test-manager` scores the manager on a demo levy with four planted bugs. `spawn --test DIR` tests a folder by hand.

## 0.7.0 (2026-10-02)

- Workflows: analysts write `.agent-grid/workflows/<name>/run.sh` and `WORKFLOW.md` (Purpose, Inputs, Outputs, Correct means, Edge cases) for each process their code runs. Analysts are briefed at the start of each managed session; changing code without a workflow sends the turn back.
- The manager now tests instead of only reading: it copies the folder to a temp folder, runs every workflow as written, checks the outputs against "Correct means", tries to break each one with altered inputs, and reruns for consistency. A workflow that fails as written goes straight back to the analyst.
- Workflows can't reference the folder by its full path. The latest failed copy is kept as `<folder>-last-failed`. Testing that can't finish is flagged, not passed.
- Manager pane shows per-workflow results. New settings: `WORKFLOW_TIMEOUT`, `TEST_TIMEOUT`, `TEST_TOOLS`, `WORKFLOW_SANDBOX`, `WORKFLOW_COPY_MAX_MB`, `WORKFLOW_KEEP_FAILED`. The installer raises the Stop hook limit to 7200 seconds.
- Folders with no code changes and no workflows keep the read-only review.

## 0.6.0 (2026-10-02)

- The reviewer is now the manager, and it comes with every spawn: a "manager" pane with a live feed (agents, recent reviews and checks, latest findings), and a read-only Claude that tries to break each analyst agent's work when it finishes.
- `--no-manager` launches without it; `REVIEW_DEFAULT=0` makes it opt-in (`--manager`). `--review` / `--no-review` still work.
- Labels: [managed], [manager reviewing], [manager flagged].

## 0.5.0 (2026-10-02)

- Reviewer agent: `spawn --review` (or a folder's `.agent-grid/review.md`) runs a second, read-only Claude after each finished turn. It reviews what changed and sends real problems back to the agent, up to `REVIEW_MAX` rounds, then flags the pane and notifies you.
- Order on every finished turn: checks (`verify.sh`), then review, then auto-push. Nothing is pushed until both pass.
- New statuses: [reviewing], [review flagged]. Workspaces remember `--review`.
- Settings: `REVIEW_MAX`, `REVIEW_TIMEOUT`, `REVIEW_MODEL`, `REVIEW_TOOLS`. Reviews are saved under `~/.local/state/agent-grid/reviews/`.

## 0.4.0 (2026-10-02)

- Status: panes show [working], [needs you], [checking], [done], or [checks failed]; the tmux status bar counts them.
- Desktop notifications when an agent finishes or needs you (Windows toast on WSL, notify-send on Linux). `NOTIFY=0` turns them off.
- Self-verification: `.agent-grid/verify.sh` runs when Claude finishes a turn; failures go back to Claude up to `VERIFY_MAX` times, and `--gh` only pushes after checks pass.
- Orchestration: `--prompt`, `--prompt-file` (per-folder TASK.md), `--send` / `--all`, and `--overview` with live previews. New keys: `Ctrl+b O` (overview), `Ctrl+b M` (message).
- One Claude hook script (`agent-hook`) now handles UserPromptSubmit, Notification, and Stop; the installer replaces the old auto-commit hook entry.

## 0.3.0 (2026-10-01)

- `spawn --save NAME` / `spawn -w NAME`: saved workspaces (base folder, folders, options). `--list` and `--forget NAME` manage them.
- `spawn --doctor`: checks tools, PATH, config, tmux and Claude hooks, GitHub login, and recent auto-push activity. Runs at the end of `install.sh`.
- `spawn --worktrees N`: N Claude agents on one repo, each in its own worktree and branch.
- Panes now stay open after the command exits (e.g. `/exit` in Claude leaves a shell). `--close` restores the old behavior.
- tmux autostart is off by default. Turn it on with `install.sh --autostart`.
- `auto-commit` logs what it did to `~/.local/state/agent-grid/auto-commit.log`, including failed pushes.
- New repos from `gh-connect` ignore `.claude/worktrees/`.
- Added LICENSE, CHANGELOG, VERSION, and a shellcheck GitHub Action.

## 0.2.0

- GitHub mode moved to `spawn --gh`: connect picked folders and auto-push per launch.
- `Ctrl+b G` opens the picker in GitHub mode; panes show an [auto-push] label.
- Removed the levy presets; agent-grid is a general tool.

## 0.1.0

- First version: `spawn`, `gh-connect`, auto-push hook, Linux and WSL installers.
