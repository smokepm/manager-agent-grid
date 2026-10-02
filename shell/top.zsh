# agent-grid: sourced at the very top of ~/.zshrc (before anything else).
export PATH="$HOME/.local/bin:$PATH"

_ag_conf="${XDG_CONFIG_HOME:-$HOME/.config}/agent-grid/config"
[ -f "$_ag_conf" ] && source "$_ag_conf"
unset _ag_conf

# Optional: open every interactive terminal in (or rejoin) one tmux session.
# Off by default; turn on with TMUX_AUTOSTART=1 in ~/.config/agent-grid/config.
if [ "${TMUX_AUTOSTART:-0}" = 1 ] && [ -z "$TMUX" ] && [ -t 1 ] && command -v tmux >/dev/null; then
  tmux new -A -s "${TMUX_SESSION:-grid}"
fi
