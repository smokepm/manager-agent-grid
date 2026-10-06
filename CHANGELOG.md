# Changelog

## 0.18.0 (2026-10-06)

- **Handoff:** the manager no longer tests every turn. Analysts work through the whole task, then hand off by ending their reply with `HANDOFF: ready for the manager` (they're told to at the start of each session). You can hand off for them with `/handoff` or `Ctrl+b H`. Fix rounds after a handoff are tested on their own. `MANAGER_WHEN=every-turn` restores the old behavior.
- **No pointless rounds:** when the analyst answers a send-back without changing any code or workflow, it comes straight to you with its reply instead of rerunning the same test. This happens in both modes.
- New: a `/handoff` command in `~/.claude/commands/` (installed by `install.sh`, removed by `uninstall.sh`), and `spawn --doctor` shows which mode the manager is in.

## 0.17.0 (2026-10-05)

- **Pick up past conversations:** `spawn -R` (or `--sessions`) asks, for each folder you pick, which past Claude conversation to resume: newest first, titled with Claude's summary or your first message, with a preview of the last few messages, or a new one. Workspaces remember `-R`, and `PICK_SESSIONS=1` makes it the default.
- **Claude Desktop sessions on WSL:** the Desktop app keeps its sessions under the Windows profile, named after Windows paths, so WSL never saw them. `spawn --import-desktop` copies them into WSL under the matching names, and it happens automatically before `-R` and `-r` (`AUTO_IMPORT_DESKTOP=0` turns that off). They're marked [desktop] in the list. `spawn --doctor` says when there are new ones.
- The installer now installs `rsync`.

## 0.16.1 (2026-10-02)

Safer tests, merged in from a parallel 0.16.0.

- **No containment, no test.** If bubblewrap isn't working, the manager runs nothing and flags the folder, and `spawn --doctor` says why. `ALLOW_UNCONTAINED=1` runs workflows uncontained with a read-only manager (no shell, no edits).
- **A tighter sandbox.** Inside a test, agent-grid itself, `~/.config/agent-grid` (settings, hidden checks, domain packs, plugins), each plugin's own folder, `~/.local/bin`, Claude's settings and CLAUDE.md, and your shell and git config are read-only; `~/.ssh`, `~/.config/gh`, `~/.aws`, and `~/.gnupg` are hidden. Nothing a test runs can rewrite your checks, the tools that run them, or the hooks that enforce them.
- **`outputs` in checks.toml:** files the workflows write that your checks read, deleted before each run so an old copy can't pass.
- **`SETUP_TOOLS_EXTRA`:** extra tools setup sessions may use without asking, for a checker of your own.
- Fixed: GitHub's shellcheck (0.9) flagged a warning in agent-hook, so the repo's check failed.

## 0.16.0 (2026-10-02)

agent-grid's first version as a general tool.

- **The grid:** `spawn` opens Claude Code in a tmux pane per folder, with workspaces, worktrees, GitHub auto-push (`--gh`), an overview of every agent, and desktop notifications.
- **The manager:** analysts write a workflow for each process their code runs. When one finishes a turn, the manager runs every workflow in a contained copy of the folder, runs your checks, and has a second Claude try to refute or break the work. Problems go back to the analyst for up to `REVIEW_MAX` rounds, then to you.
- **Your checks** (`.agent-grid/checks.toml`, `agent-check`): protected paths for your own tests and specs, check commands that must pass, and golden tests (known inputs with known-good outputs). Analysts can read your checks but a hook blocks them from changing them, and they're told to stop and explain when a check looks wrong.
- **Hidden checks** (`spawn --hidden`): scripts of your own kept outside the folder, where analysts can't read them. A failure comes to you.
- **Setup** (`spawn --setup`): Claude works out what "correct" means from your tests, specs, and known-good outputs, writes `checks.toml`, and summarizes where every check came from for you to confirm. It runs with auto memory off and never takes rules from the code or from earlier sessions.
- **Domain packs and plugins:** extra setup steps and extra checks for one kind of project, added in `~/.config/agent-grid/` without changing agent-grid.
- **Clear status:** each pane and the manager pane say in plain words what's happening and what the last result covered.
