#!/usr/bin/env bash
# uninstall.sh: remove agent-grid's tools, shell/tmux hooks, and Claude auto-push hook.
# Leaves installed packages, oh-my-zsh, Claude Code, your venv, and your config alone.
set -e
ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

for l in "$HOME"/.local/bin/*; do
  if [ -L "$l" ] && [[ "$(readlink "$l")" == "$ROOT/bin/"* ]]; then rm "$l"; echo "removed $l"; fi
done

[ -f ~/.zshrc ] && sed -i '/# >>> agent-grid top >>>/,/# <<< agent-grid top <<</d; /# >>> agent-grid >>>/,/# <<< agent-grid <<</d' ~/.zshrc
[ -f ~/.tmux.conf ] && sed -i '/# >>> agent-grid >>>/,/# <<< agent-grid <<</d' ~/.tmux.conf
echo "removed shell and tmux hooks"

S=~/.claude/settings.json
if [ -f "$S" ] && command -v jq >/dev/null && jq empty "$S" 2>/dev/null; then
  t=$(mktemp)
  jq 'def strip: map(select(([.hooks[]?.command] | any(test("auto-commit|agent-hook"))) | not));
      reduce ("Stop", "Notification", "UserPromptSubmit", "PreToolUse") as $e (.;
        if (.hooks[$e] // null) then .hooks[$e] |= strip else . end
        | if (.hooks[$e] // null) == [] then del(.hooks[$e]) else . end)
      | if (.hooks // {}) == {} then del(.hooks) else . end' "$S" > "$t" && cat "$t" > "$S" && rm -f "$t"
  echo "removed the agent-grid Claude hooks"
fi

echo "Done. Your settings are still in ${XDG_CONFIG_HOME:-$HOME/.config}/agent-grid/ (delete it if you like)."
