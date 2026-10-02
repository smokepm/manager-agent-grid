# agent-grid

Run several Claude Code agents side by side in tmux, one per folder, with a manager that oversees them: it tries to refute or break each analyst's work and sends problems back. Add `--gh` to also connect those folders to GitHub and auto-push Claude's code changes. Works on Linux (Fedora, Ubuntu/Debian) and on Windows through WSL.

```
spawn                 pick folders, get a tmux grid with Claude running in each
spawn --gh            same, plus connect each folder to GitHub and auto-push changes
spawn --no-manager    same grid, without the manager
spawn --worktrees 3   three agents on one repo, each on its own branch
spawn -w work         reopen a saved workspace
spawn --overview      every agent's status at a glance; jump to the one that needs you
spawn --doctor        check that everything is set up
```

## What you get

- **spawn**: a folder picker that opens each selection in a tiled tmux pane (or tab) running Claude, or any command you choose. When a command exits (like `/exit` in Claude), the pane stays as a normal shell.
- **GitHub mode, `spawn --gh`**: connects each picked folder to a repo (choose an existing one, or create a private one), then commits and pushes code after every Claude turn in those panes. Data files never leave your machine. Plain `spawn` never touches GitHub.
- **Worktrees, `spawn --worktrees N`**: N agents on the same repo, each in its own git worktree and branch, so they don't edit the same files.
- **Workspaces**: save a base folder, folder selection, and options under a name, and reopen them with one command.
- **Status and notifications**: every pane shows **[working]**, **[needs you]**, **[done]**, or **[checks failed]**, the status bar counts them, and you get a desktop notification when an agent finishes or needs you.
- **Self-verification**: put a check script in a folder's `.agent-grid/verify.sh`, and Claude can't finish a turn until it passes. Failures go back to Claude to fix, automatically.
- **A manager with every launch**: analysts write a workflow for each process their code runs. When one finishes, the manager runs every workflow in a contained copy of the folder, runs your own checks and a backtest against last year's certified roll, then a second Claude tries to refute or break the work. Real problems go back to the analyst, and nothing is pushed until the work survives.
- **Orchestration**: start every agent on the same prompt or on each folder's own `TASK.md`, message all agents at once, and see everything in one overview with live previews.
- **Doctor**: one command that checks the whole setup and shows recent auto-push activity.
- **Environment**: zsh with oh-my-zsh and Powerlevel10k, a themed tmux with handy key bindings, a Python venv (pandas, openpyxl, jupyter), Claude Code, the GitHub CLI, a Nerd Font, and VS Code terminal settings.
- **WSL extra**: `winpy` runs Windows Python, for scripts that need Windows-only libraries like win32com or xlwings.

## Install

### Windows (WSL)

1. Clone or download this repo on Windows.
2. In PowerShell, from the repo's `windows` folder:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
   ```
   This installs the font and VS Code extensions, then WSL with the latest Fedora (`-Distro Ubuntu` for Ubuntu). Installing WSL needs an Administrator PowerShell; if that step is skipped, rerun as admin. Restart if asked.
3. Open the distro from the Start menu, create your Linux user, and run the command the script printed. It looks like:
   ```bash
   cp -r "/mnt/c/Users/<you>/agent-grid" ~/agent-grid && bash ~/agent-grid/install.sh
   ```

### Linux (Fedora, Ubuntu/Debian)

```bash
git clone https://github.com/<owner>/agent-grid ~/agent-grid
bash ~/agent-grid/install.sh
```

For a private repo, either download the ZIP, or install the GitHub CLI first (`sudo dnf install gh` or `sudo apt install gh`), run `gh auth login`, then `gh repo clone <owner>/agent-grid ~/agent-grid`.

### Both

The installer asks one question, an optional GitHub org for `spawn --gh` (blank means your personal account), sets everything up, and finishes with a `spawn --doctor` report.

| Option | Effect |
|---|---|
| `--no-shell` | Skip oh-my-zsh, Powerlevel10k, and changing your login shell |
| `--no-vscode` | Skip VS Code install, settings, and extensions |
| `--autostart` | Open every new terminal inside tmux (off by default) |
| `--no-autostart` | Turn that back off |

Then:

1. Open a new terminal (on Linux, log out and back in first). The Powerlevel10k wizard runs once. If you use `--autostart`, choose **Instant prompt: Off**.
2. `claude` to log in.

The first `spawn --gh` walks you through `gh auth login` if you haven't done it.

## Usage

### spawn

| Command | What it does |
|---|---|
| `spawn` | Picker for folders under the current directory, then Claude in each |
| `spawn -b ~/projects` | Picker for folders under `~/projects` |
| `spawn api web` | Open those folders directly, no picker |
| `spawn --gh` | GitHub mode: connect the folders and auto-push Claude's changes |
| `spawn --no-manager` | Launch without the manager (no reviews, no manager pane) |
| `spawn --worktrees 3` | Three agents on the current repo, each on its own branch |
| `spawn -r` | Resume each folder's last conversation (fresh Claude if none) |
| `spawn -c "npm run dev"` | Run any command instead of Claude |
| `spawn -c ""` | Plain shells |
| `spawn -t` | One tab per folder instead of a tiled grid |
| `spawn --close` | Close each pane when its command exits, instead of keeping a shell |
| `spawn --prompt "text"` | Start every agent on the same prompt |
| `spawn --prompt-file TASK.md` | Start each agent on its own folder's `TASK.md` |
| `spawn --overview` | All agents, most urgent first, with a live preview; Enter jumps there |
| `spawn --test [DIR]` | Run the manager's test on a folder now |
| `spawn --watch [DIR]` | Follow the manager's reviews of a folder live |
| `spawn --spot [DIR]` | Your hand-calculated parcels for a folder, kept outside it |
| `spawn --setup [DIR]` | Have Claude set up a folder's checks, with a summary for you to confirm |
| `levy-check selftest` | Plant errors in copies of the rolls and see which checks catch them |
| `levy-check init` | Start a folder's `checks.toml` by hand |
| `levy-check` | Run a folder's rules on its current roll |
| `spawn --clean` | Delete every test copy |
| `spawn --send "text"` | Message running agents (pick which, or `--all`) |
| `spawn -h` | All options |

Options combine, e.g. `spawn --gh -r -b ~/projects`.

In the picker: type to filter, `Enter` adds a folder, `Tab` marks several, `Esc` or **[ Done ]** launches. The preview shows each folder's git status and files. `.` is the base folder itself.

### Workspaces

```bash
spawn --save work -b ~/projects api web     # save these folders (and launch them)
spawn --save clients -b ~/clients           # pick nothing to save just the base folder
spawn -w work                               # reopen
spawn -w work -r --gh                       # options given with -w override what's saved
spawn --list                                # list workspaces
spawn --forget work                         # delete one
```

A workspace saved without folders opens the picker under its base folder, which makes a handy shortcut for a directory you work in often.

### GitHub mode: `spawn --gh`

1. For each folder you pick, spawn checks for a GitHub remote. Connected folders go straight through. For the rest, it opens a picker of your org's repos (filtered by folder name) to connect to, or creates a new private repo.
2. The panes open with auto-push on, marked **[auto-push]** on the pane border.
3. Every time Claude finishes a turn in one of those panes, its code changes are committed and pushed.

What gets pushed:

- **Only code:** changes to tracked files, plus new files matching `CODE_EXT` (by default common source files: `py md toml ts tsx js jsx sh sql r R go rs`). Spreadsheets, CSV, PDF, JSON, and anything else stay local unless already tracked.
- New repos get a `.gitignore` that keeps data files, `Archive/`, `__pycache__/`, and Claude worktrees out.
- Connecting to an existing repo never changes your files. It lists what differs, and the next Claude turn pushes that list, so review it first.

Auto-push is per pane. The same folder opened with plain `spawn` (or a plain `claude`) doesn't push. If you `/exit` and start `claude` again in an [auto-push] pane, it still pushes. To connect a folder without launching anything, run `gh-connect` inside it (`gh-connect -h` for options).

Every auto-push attempt is logged to `~/.local/state/agent-grid/auto-commit.log`, and `spawn --doctor` shows the latest entries, including failed pushes and why.

### Worktrees: `spawn --worktrees N`

Run it inside a git repo (or pass `-b` or a folder). Each pane runs `claude --worktree agent-1`, `agent-2`, and so on, so every agent works in its own copy of the repo on its own branch. Panes are labeled `repo: agent-1` etc. Add `--gh` to push each agent's branch as it works.

### Status and notifications

Every agent pane reports what it's doing on its border:

| Label | Meaning |
|---|---|
| **[setting up checks]** | A setup Claude is building this folder's checks (`spawn --setup`) |
| **[checks ready: your turn]** | Setup has posted its summary and questions: answer them, then type `/exit` |
| **[working]** | Claude is working on your last message |
| **[checking]** | Running the folder's verification |
| **[manager testing]** | The manager is testing this agent's last change; the agent waits for the verdict |
| **[manager queued for Excel]** | Waiting for another folder's Excel test to finish |
| **[needs you]** | Claude is waiting for permission or input |
| **[done]** | Finished its turn |
| **[checks failed]** | Verification still failed after `VERIFY_MAX` tries, handed back to you |
| **[manager flagged]** | Handed back to you: the manager still sees problems after `REVIEW_MAX` rounds, the analyst stopped without writing a workflow it was asked for, or your hand-calculated parcels don't match |

The tmux status bar counts them (e.g. `2 need you  3 done`). When an agent finishes or needs you and you're not looking at its pane, you get a desktop notification (Windows toast on WSL, `notify-send` on Linux). Turn notifications off with `NOTIFY=0` in the config.

### Self-verification

Add a check to any folder:

```bash
mkdir -p .agent-grid
cat > .agent-grid/verify.sh << 'CHECK'
#!/usr/bin/env bash
# Exit 0 if the work is right, non-zero (with a helpful message) if not.
python3 -m pytest -q
CHECK
```

Every time Claude finishes a turn in that folder, the check runs (only if files changed since it last passed). If it fails, Claude is sent back with the output and told to fix the cause, up to `VERIFY_MAX` times (default 3). Only after the check passes does the turn end, and only then does `--gh` auto-push, so failing work never reaches GitHub. If it still fails, the pane shows **[checks failed]** and you're notified.

Good checks compare outputs against known-good results: tests, a reconciliation against last year's or hand-built totals, a schema check on an export. Results are logged and shown by `spawn --doctor`.

### The manager

Every `spawn` comes with a manager. You'll see a pane labeled **manager**, and agent panes marked **[managed]**. The agents doing the work are the analysts. The manager's only job is to refute or break their work.

Each review is done by a fresh Claude, started when an analyst finishes a turn that changed something. That's deliberate: a reviewer that sat through the analyst's reasoning tends to adopt it, while a fresh one sees only the work, your checks, and a written record of earlier rounds (see below). The manager pane is the shared view of all of it.

#### Workflows: the analyst's hand-off

A workflow is a repeatable run the manager can execute, for example one levy run. The analyst writes one for each process its code runs:

```
.agent-grid/workflows/levy-run/
  run.sh        the exact commands that produce the outputs, using paths relative to the folder
  WORKFLOW.md   Purpose, Inputs, Outputs, Correct means, Edge cases
```

Analysts are told about this at the start of each managed session. Changing code without a workflow sends the turn back.

#### Your checks: rules and a backtest

The analyst writes "Correct means," so on its own it can share the analyst's misunderstandings. Your checks are the independent part, and they're plain code, so they're exact and never raise false alarms.

You don't have to write them by hand. When you launch a folder that has no checks, `spawn` asks:

```
oak-hills has no checks for the manager yet. Have Claude set them up first? [Y/n/never]
```

Say yes, and before the analyst starts, a setup Claude finds the roll and its columns, last year's certified roll, and last year's inputs. It writes `checks.toml`, copies the backtest files in, runs `levy-check` to confirm everything reads, and runs `levy-check selftest` to see what the checks can't catch. While it works the pane shows **[setting up checks]**; when its summary is up, **[checks ready: your turn]**. The summary lists each check and where its number came from (file, sheet, cell, or RMA page and section), anything it couldn't find or had to assume, each known difference, and what selftest found the checks miss. Look that over, correct anything it got wrong, and type `/exit`. The analyst then starts in the same pane. Run `spawn --setup ~/levies/oak-hills` any time to set up or review a folder's checks; "never" stops the question for that folder.

The setup Claude is told to build the checks only from the data, last year's certified results, and the RMA: never from the levy code, and never from Claude memory notes or earlier sessions, since either could carry the code's mistakes. It runs with Claude's auto memory off, so nothing it learns leaks into the analyst's sessions. It searches only the folder and the one it sits in, and asks you for anything it can't find there. Its summary is worth your one look: if it picks the wrong certified roll, everything after trusts it.

To write them by hand instead, `levy-check init` creates a commented `checks.toml` to fill in.

`checks.toml` has these parts:

- **The roll:** which file the workflow writes (.csv or .xlsx) and which columns hold the APN, the levy, and optionally the max tax, units, and rate.
- **Rules every roll must meet:** each APN once (or, where a parcel can rightly appear more than once, each line once by `unique_by`, e.g. APN + account); no blank APNs, negatives, or fractions of a cent; no levy above the max tax; max tax equals units × rate (rounded half up by default); the total ties to this year's levy requirement; every parcel in the county export is on the roll and nothing else is.
- **Totals by group (optional):** expected totals per district, zone, or fund. A folder that levies several districts can tie out overall while one is over and another under; this catches that.
- **Max rates (optional):** each rate class's maximum rate per unit from the RMA, either as stated for the year or as a base rate, base year, escalator, and rounding. levy-check works out the max itself, so a wrong escalator can't hide in the roll's own columns, and every parcel's levy must be at most its units × its max rate. The backtest checks last year's roll against last year's max too.
- **A backtest:** last year's certified roll (the one that went to the county), plus last year's version of each input the workflow reads (county export, rates, and so on), kept in `.agent-grid/backtest/`.
- **Known differences (optional):** certified parcels the code shouldn't reproduce, one line each with the reason: last year's roll got them wrong, or someone decided them by hand. Their amounts aren't compared. If the certified roll is over its own max for some parcels, the backtest says so and tells you to list them here, so the code is never required to repeat an overcharge.

```toml
[backtest]
expected = ".agent-grid/backtest/certified_roll.csv"
expected_apn = "Parcel"
expected_amount = "Total Levy"

[backtest.inputs]
"inputs/county_export.csv" = ".agent-grid/backtest/county_export.csv"
"inputs/rates.csv" = ".agent-grid/backtest/rates.csv"
```

The backtest uses the folder's workflow automatically, and starts once the analyst has written one; name it with `workflow = "..."` only if the folder has more than one. The analyst is told to write the roll exactly where `[roll]` says.

On every test, the rules run on this year's output. The backtest then puts last year's inputs in place in a separate copy, runs the workflow, and compares the result with the certified roll parcel by parcel, to the cent. Because `levy_core.py` is shared, a change made for one district that breaks another shows up in that district's backtest the same turn. APNs match with or without dashes, and `$1,203.44`-style amounts are read as numbers. Run `levy-check` in the folder yourself any time to see the rule results.

`checks.toml`, `.agent-grid/backtest/`, and `review.md` are yours, and read-only to analysts: agent-grid blocks their edits to them, and blocks shell commands that would change them. Analysts can still read them, because seeing which parcels fail is how they fix the code. They're also told that if a check looks wrong, they should stop and say so rather than change the code to fit it. A script that writes there anyway is caught at the next test: the result says your files changed and you're notified. They're never auto-pushed to GitHub. A folder without `checks.toml` still gets tested, but every pass says only the analyst's own criteria were used.

**Test the tests.** `levy-check selftest` plants errors in copies of the rolls (nothing on disk changes): a parcel dropped, billed twice, or added from outside the district; one levy 10% high; every levy 2% high, as when an escalator is applied twice; a fraction of a cent; a negative levy; a blank APN; a parcel a cent over its max; a parcel in the wrong rate class; and, in the backtest, a parcel off by a cent, dropped, or added. It reports which checks caught each one and which got through. What gets through is the gap your review and the manager have to cover.

**Your hand-calculated parcels.** Work a few parcels out yourself from the RMA, one per rate class, and save them with `spawn --spot ~/levies/oak-hills`. They're kept in `~/.config/agent-grid/spot/`, outside the folder, and agent-grid blocks analysts from reading them, so the code can't be tuned to them. On every test the manager compares the roll with them. A mismatch comes to you, not the analyst, because either the code or your figure is wrong. Update them each fiscal year; the file goes by the folder's path, so run `spawn --spot` again after moving a folder.

What checks can't cover is anything new this year: a new zone, an escalator, annexed or split parcels. Last year can't vouch for those. Max rates and your hand-calculated parcels cover part of it; the manager aims at the rest, and your review of the final roll is still the last check.

#### What happens when an analyst finishes a turn

1. **Checks.** `verify.sh` runs, if the folder has one.
2. **Workflow checks.** These cost nothing and run before anything else:
   - each workflow has both files and a "Correct means" section;
   - nothing refers to the folder by its full path, which would make a test in a copy touch the real files.

   Problems go back to the analyst.
3. **Snapshot.** The folder is copied as it is right now. Folders on a Windows drive under WSL get their copy on the Windows side, so `winpy` and Excel can open the files.
4. **The analyst waits.** The pane shows **[manager testing]** until the verdict. Your other analysts keep working.
5. **Baseline.** Each `run.sh` runs once, exactly as written. Any roll left over from the analyst's own runs is removed first, so a workflow that stops writing its roll can't pass on a stale copy. A failure goes straight back with the error.
6. **Your checks and the backtest.** If either fails, it goes straight back to the analyst with the failing parcels, without spending a manager review. If `checks.toml` itself is unusable (a column renamed, a file missing), it comes to you instead.
7. **Your hand-calculated parcels**, if you've saved any with `spawn --spot`. A mismatch comes to you; the analyst isn't told.
8. **Refute or break it.** The manager, a second Claude, works in the copy with full tools:
   - checks the outputs against "Correct means" and your `review.md`, by computing rather than reading the code;
   - goes after what your checks can't see: anything new this year, and rules in the code they don't test;
   - feeds in altered inputs (duplicates, blanks, zero and negative amounts, values at and over limits, missing columns) and runs `levy-check` on the results, so your rules judge its attacks too;
   - reruns to confirm the results don't change, and reads the changed code for wrong rules.
9. **Verdict.**
   - Each round's findings and the analyst's reply to them are kept as a record. The next review gets that record and is told to verify each earlier finding is really fixed, and to raise a disputed one again only with new evidence that answers the analyst's argument. A pass clears the record.
   - Problems go straight back to the analyst, which picks up where it left off.
   - After `REVIEW_MAX` rounds (default 2), the pane shows **[manager flagged]** and you're notified.
   - A test that can't finish, from a timeout for example, is also flagged, never passed.
   - A pass is logged with what it covered, e.g. "passed: ran 1 workflow(s) in a copy; your checks passed; backtest passed; your hand-calculated parcels matched; the manager found nothing". If something was missing, like a backtest, the line says so.
10. **Push.** With `--gh`, only a version that passed is pushed. If you edit a file by hand while a test runs, that edit isn't pushed until the next test has covered it.

A change to your checks or backtest files triggers a new test even if no code changed. In a folder with no workflows, code changes send the turn back for one. If the analyst then stops without changing anything, it comes straight to you with its reply, instead of being asked again. Where no code changed, the manager reads the changed text files (notes, configs), logged as "read-only review ... nothing was run". If only data or output files changed, it logs "nothing to review" rather than calling that a pass.

#### Containment

Each test runs inside [bubblewrap](https://github.com/containers/bubblewrap). The test copy is writable, and so are your home directory (Claude needs it) and `/tmp`. Everything else is read-only: the real folder, every folder beside it, and every Windows drive. So a script that writes to `S:\` by mistake fails instead of writing. `spawn --doctor` confirms it works.

Windows programs started from WSL (`winpy`, Excel) run on the Windows side, outside any Linux containment, so they could still write anywhere on Windows. The manager is told that writing outside the folder is a problem, but keeping outputs inside the folder is the real protection.

Excel tests take turns: if two folders' workflows use `winpy`, `win32com`, or `xlwings`, the second waits (**[manager queued for Excel]**), because Excel automation breaks when two runs drive it at once.

#### Client data

Test copies and saved reviews contain client data, so they're kept only as long as they're useful:

- **Passing copies** are deleted immediately.
- **The latest failed copy** for each folder is kept as `<folder>-last-failed` for `WORKFLOW_KEEP_DAYS` (default 3), so you can rerun the manager's inputs. The review file says where it is.
- **Saved reviews** are deleted after `REVIEW_KEEP_DAYS` (default 30).

Copies are private to your user. `spawn --clean` deletes every copy now.

#### Watching a review

```bash
spawn --watch ~/levies/oak-hills      # or Ctrl+b W in that analyst's pane
```

This shows a review as it happens: each step the hook takes (the baseline run, your checks, the backtest), then everything the manager does (its reasoning, each command it runs, and the first lines of what came back), then the verdict. It stays open and picks up each new review for that folder, so a split with `Ctrl+b W` next to an analyst works like having its manager beside it. With no folder, it watches the pane you're in, or lets you pick an agent. Live logs contain client data and are kept for `REVIEW_KEEP_DAYS`.

#### Folder rules and the feed

Give the manager folder-specific rules in `.agent-grid/review.md`:

```markdown
Charges must never exceed the maximum rate in the RMA.
Every parcel in the input export must appear exactly once in the output.
```

A folder with a `review.md` is always managed, even with `--no-manager`. Put rules a computer can check in `checks.toml`, and anything else for the manager in `review.md`.

The manager pane shows each agent's status in plain words with its last result (for example "CHECKS READY: YOUR TURN" or "done ... last: passed: ..."), then recent workflow results, reviews, and checks for the folders on screen (entries for folders you've closed stay in the log but drop off the pane), and the latest findings. Press `o` for the overview, `r` to open the latest findings in full, `q` to close it. Reviews are saved in `~/.local/state/agent-grid/reviews/`. To test a folder by hand, without an analyst, run `spawn --test ~/levies/oak-hills`.

#### Costs and limits

A test reruns your processes several times and uses your Claude plan, so expect several minutes and some usage per finished turn that changed something. `WORKFLOW_TIMEOUT` caps each run and `TEST_TIMEOUT` caps the manager. To make the manager opt-in, set `REVIEW_DEFAULT=0` and launch with `spawn --manager` when you want it.

### Orchestration

```bash
spawn -w clients --prompt-file TASK.md      # each folder's own TASK.md as the first prompt
spawn api web --prompt "Upgrade to v3 and run the tests"
spawn --send "Summarize what you changed"   # pick agents (all preselected)
spawn --send "Pause and commit" --all
spawn --overview                            # status + live preview; Enter jumps to that pane
```

A per-folder `TASK.md` works like a spec: the goal, the inputs, what "done" looks like, and how to check it. Folders without one start with a normal, empty Claude.

### tmux keys

Press `Ctrl+b`, release, then:

| Key | Action |
|---|---|
| `A` | spawn picker as a popup, starting from this pane's folder |
| `G` | Same, in GitHub mode (`spawn --gh`) |
| `O` | Overview of every agent, most urgent first; Enter jumps to it |
| `M` | Send a message to agents |
| `W` | Watch this agent's manager live, in a split beside it |
| `z` | Zoom this pane / back to the grid |
| arrows | Move between panes (or click) |
| `S` | Sync typing to every pane, e.g. to send `/exit` to all. Press again to turn off. |
| `K` | Kill the whole session (asks first) |
| `x` | Close just this pane |
| `d` | Detach. Agents keep running; `tmux attach -t grid` (or `spawn`) brings you back. |
| `c` / `%` / `"` | New tab / split side by side / split top-bottom, in the current folder |

### Shell extras

`chat` opens a general Claude conversation in `~/chat`, `chats` lists past ones, `ask <question>` gives a one-shot answer, `ll`, and `zshrc` edits and reloads your config.

## Configuration

Settings live in `~/.config/agent-grid/config`; workspaces in `~/.config/agent-grid/workspaces/`.

| Setting | Meaning |
|---|---|
| `GH_ORG` | Repo owner for `spawn --gh` (blank = your account) |
| `CODE_EXT` | File types auto-push may add, separated by `\|` |
| `TMUX_AUTOSTART` | `1` opens every terminal inside tmux, `0` (default) doesn't |
| `TMUX_SESSION` | Session name (default `grid`) |
| `SCREENSHOTS` | Where Claude looks when you say "latest screenshot" |
| `NOTIFY` | `1` (default) sends desktop notifications, `0` doesn't |
| `VERIFY_MAX` | How many times a failing check goes back to Claude (default 3) |
| `VERIFY_TIMEOUT` | Seconds a check may run (default 600) |
| `REVIEW_DEFAULT` | `1` (default) launches the manager with every spawn, `0` makes it opt-in |
| `REVIEW_MAX` | Rounds the manager's findings go back to the analyst (default 2) |
| `REVIEW_TIMEOUT` | Seconds a read-only review may take (default 300) |
| `REVIEW_MODEL` | Model for the manager (blank = your default) |
| `REVIEW_TOOLS` | Tools for read-only reviews (default `Read,Grep,Glob`) |
| `WORKFLOW_TIMEOUT` | Seconds each workflow run may take (default 900) |
| `TEST_TIMEOUT` | Seconds the manager may spend testing (default 2400) |
| `TEST_TOOLS` | Tools the manager has in the copy (default `Read,Grep,Glob,Bash,Edit,Write`) |
| `CONTAIN` | `1` (default) runs tests inside bubblewrap; `0` turns that off |
| `EXCEL_WAIT` | Seconds an Excel test waits for another to finish (default 3600) |
| `WORKFLOW_SANDBOX` | Where copies are made (blank = system temp, or Windows temp for folders on a Windows drive) |
| `WORKFLOW_COPY_MAX_MB` | Largest folder to copy (default 2000); bigger folders get a read-only review |
| `WORKFLOW_KEEP_FAILED` | `1` (default) keeps the latest failed copy for you to inspect |
| `WORKFLOW_KEEP_DAYS` | Days a failed copy is kept (default 3) |
| `REVIEW_KEEP_DAYS` | Days saved reviews are kept (default 30) |
| `LEVY_SOFTWARE` | The name of your levy software (e.g. the system your certified rolls come from), so setup knows what to look for. Blank = not named |
| `ANALYST_AUTO_MEMORY` | `1` (default) leaves Claude's auto memory on for analysts; `0` turns it off. Setup sessions and the manager always run without it |
| `WIN_PY` | WSL only: Windows `python.exe` used by `winpy` |

Your own tmux settings go in `~/.tmux.conf` below the agent-grid block. Claude style rules are in `config/claude-style.md` (copied into `~/.claude/CLAUDE.md` on install), so edit them to taste.

## Updating

The tools and configs are linked from this repo, so:

```bash
git -C ~/agent-grid pull && bash ~/agent-grid/install.sh
```

Re-running keeps your answers, doesn't duplicate anything, and removes links to tools that no longer exist. `spawn --version` shows what you're on; see [CHANGELOG.md](CHANGELOG.md).

## Uninstall

```bash
bash ~/agent-grid/uninstall.sh
```

Removes the tools, shell and tmux hooks, and the Claude hooks. Packages, oh-my-zsh, Claude Code, your venv, config, and workspaces are left alone.

## Troubleshooting

Start with `spawn --doctor`. It names the problem and the fix for most of these.

| Problem | Fix |
|---|---|
| `command not found` right after install | Open a new terminal, or run `rehash` |
| `Ctrl+b` toggles the VS Code sidebar | Re-run `install.sh` (it sets `commandsToSkipShell`), then restart VS Code |
| A pane doesn't auto-push | Only panes launched with `--gh` push (look for **[auto-push]** on the border). `spawn --doctor` shows what the hook did |
| No status labels, notifications, or workflow tests | Re-run `install.sh` (it raises the hook time limit for workflow tests), restart Claude sessions that were open before install (hooks load at startup), then check `spawn --doctor` |
| A check keeps sending Claude back | Run `.agent-grid/verify.sh` yourself to see the failure. `VERIFY_MAX` caps the retries |
| The manager flags something you disagree with | Press `r` in the manager pane to read it, tell the agent why it's fine, or launch with `--no-manager` |
| Turns keep coming back about a missing workflow | The analyst changed code without a workflow. Ask it to write `.agent-grid/workflows/<name>/` (see The manager) |
| A workflow passes for the analyst but fails for the manager | It probably depends on something outside the folder, or on `.git`/a venv that isn't copied. Open `<folder>-last-failed` in the temp folder and run its `run.sh` |
| "couldn't finish testing" | Raise `TEST_TIMEOUT` or `WORKFLOW_TIMEOUT`, or split a long run into smaller workflows |
| "Your checks ... changed since the last test" and you didn't change them | An analyst edited them. Restore your copy (or `git checkout .agent-grid/checks.toml`) and tell the analyst |
| The backtest fails but last year's numbers are right | Something the workflow reads changed this year and isn't swapped in. Add last year's version under `[backtest.inputs]` |
| "checks.toml can't be used" | Run `levy-check` in the folder to see why (often a renamed column) |
| A rule flags blank amounts on an .xlsx roll | The workbook was written by a script and never calculated. Have the workflow write values, or save it in Excel |
| Doctor says bubblewrap can't run (Ubuntu 24.04+) | `echo 'kernel.apparmor_restrict_unprivileged_userns=0' \| sudo tee /etc/sysctl.d/60-agent-grid.conf && sudo sysctl --system`, or `CONTAIN=0` |
| `winpy` workflows fail only under the manager | Run `spawn --doctor`. If Windows programs don't start inside containment, set `CONTAIN=0` |
| "push failed" in the doctor log | Run `git push` in that folder to see the full error |
| `$'\r': command not found` (WSL) | The scripts got Windows line endings: `sed -i 's/\r$//' ~/agent-grid/install.sh ~/agent-grid/bin/*` |
| tmux sessions gone | WSL or the machine restarted. Conversations are saved: `spawn -r` (or `spawn -w NAME -r`) resumes them |

## License

MIT. See [LICENSE](LICENSE).
