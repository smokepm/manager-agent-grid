# agent-grid: sourced at the end of ~/.zshrc.
[ -f "$HOME/.venv/bin/activate" ] && [ -z "$VIRTUAL_ENV" ] && source "$HOME/.venv/bin/activate"

# WSL: Windows folders look world-writable; stop ls from highlighting them.
[ -n "$WSL_DISTRO_NAME" ] && export LS_COLORS="${LS_COLORS}:ow=01;34:"

alias ll='ls -lah'
alias zshrc='${EDITOR:-nano} ~/.zshrc && source ~/.zshrc'
alias chat='mkdir -p ~/chat && cd ~/chat && claude'
alias chats='mkdir -p ~/chat && cd ~/chat && claude --resume'
ask() { claude -p "$*"; }
