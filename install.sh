#!/usr/bin/env bash
# install.sh: set up agent-grid on Linux or WSL (Fedora, or Ubuntu/Debian).
#
# Usage: bash install.sh [--no-shell] [--no-vscode] [--autostart | --no-autostart]
#   --no-shell      skip oh-my-zsh, Powerlevel10k, and changing your login shell
#   --no-vscode     skip VS Code install, settings, and extensions
#   --autostart     open every new terminal inside tmux (off by default)
#   --no-autostart  turn that back off
#
# Nothing connects to or pushes to GitHub unless you launch with `spawn --gh`.
# Safe to re-run; re-runs keep your previous answers.

set -e

ROOT="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-grid"
CONF="$CONF_DIR/config"
BIN="$HOME/.local/bin"
STAMP="$(date +%Y%m%d%H%M%S)"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m!!  %s\033[0m\n' "$*"; }
add_line() { grep -qxF -- "$1" "$2" 2>/dev/null || echo "$1" >> "$2"; }
backup() { if [ -e "$1" ]; then cp -a "$1" "$1.bak.$STAMP"; fi; }

[ "$(id -u)" -ne 0 ] || { echo "Run this as your normal user, not root."; exit 1; }

# Previous answers (re-runs keep them as defaults)
mkdir -p "$CONF_DIR" "$BIN"
# shellcheck disable=SC1090
if [ -f "$CONF" ]; then . "$CONF"; fi

SHELL_SETUP=1; VSCODE=1; AUTOSTART="${TMUX_AUTOSTART:-0}"
for arg in "$@"; do
  case "$arg" in
    --no-shell)     SHELL_SETUP=0 ;;
    --no-vscode)    VSCODE=0 ;;
    --autostart)    AUTOSTART=1 ;;
    --no-autostart) AUTOSTART=0 ;;
    -h|--help)      awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg (try --help)"; exit 1 ;;
  esac
done

# ------------------------------------------------------------------
IS_WSL=0
if [ -n "$WSL_DISTRO_NAME" ] || grep -qi microsoft /proc/version 2>/dev/null; then IS_WSL=1; fi
if command -v dnf >/dev/null; then PM=dnf
elif command -v apt-get >/dev/null; then PM=apt
else echo "Supported: Fedora (dnf) and Ubuntu/Debian (apt)."; exit 1; fi

if [ $IS_WSL -eq 1 ]; then step "Platform: WSL (${WSL_DISTRO_NAME:-unknown}) with $PM"
else step "Platform: Linux with $PM"; fi
sudo -v

# ------------------------------------------------------------------
step "Settings"
if [ $IS_WSL -eq 1 ] && [ ! -d "${WIN_HOME:-/nonexistent}" ]; then
  WIN_HOME=""
  CMD_EXE=/mnt/c/Windows/System32/cmd.exe
  if [ -x "$CMD_EXE" ]; then
    p=$(cd /mnt/c && "$CMD_EXE" /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')
    [ -n "$p" ] && WIN_HOME=$(wslpath "$p")
  fi
  [ -d "${WIN_HOME:-/nonexistent}" ] || read -rp "Windows home folder as a Linux path (e.g. /mnt/c/Users/YOU): " WIN_HOME
fi
if [ $IS_WSL -eq 1 ]; then echo "Windows home: $WIN_HOME"; fi

read -rp "GitHub org for spawn --gh repos (blank = your personal account) [${GH_ORG:-}]: " ans
GH_ORG="${ans:-${GH_ORG:-}}"

if [ $IS_WSL -eq 1 ]; then SHOTS="$WIN_HOME/Pictures/Screenshots"; else SHOTS="$HOME/Pictures/Screenshots"; fi

backup "$CONF"
cat > "$CONF" << EOF
# agent-grid settings. Read by the tools and your shell; edit freely.
TMUX_AUTOSTART=$AUTOSTART
TMUX_SESSION="${TMUX_SESSION:-grid}"
SCREENSHOTS="$SHOTS"
GH_ORG="${GH_ORG:-}"
CODE_EXT="${CODE_EXT:-py|md|toml|ts|tsx|js|jsx|sh|sql|r|R|go|rs}"
NOTIFY=${NOTIFY:-1}
VERIFY_MAX=${VERIFY_MAX:-3}
VERIFY_TIMEOUT=${VERIFY_TIMEOUT:-600}
REVIEW_DEFAULT=${REVIEW_DEFAULT:-1}
REVIEW_MAX=${REVIEW_MAX:-2}
REVIEW_TIMEOUT=${REVIEW_TIMEOUT:-300}
REVIEW_MODEL="${REVIEW_MODEL:-}"
REVIEW_TOOLS="${REVIEW_TOOLS:-Read,Grep,Glob}"
WORKFLOW_TIMEOUT=${WORKFLOW_TIMEOUT:-900}
TEST_TIMEOUT=${TEST_TIMEOUT:-2400}
TEST_TOOLS="${TEST_TOOLS:-Read,Grep,Glob,Bash,Edit,Write}"
CONTAIN=${CONTAIN:-1}
ALLOW_UNCONTAINED=${ALLOW_UNCONTAINED:-0}
SETUP_TOOLS_EXTRA="${SETUP_TOOLS_EXTRA:-}"
EXCEL_WAIT=${EXCEL_WAIT:-3600}
WORKFLOW_SANDBOX="${WORKFLOW_SANDBOX:-}"
WORKFLOW_COPY_MAX_MB=${WORKFLOW_COPY_MAX_MB:-2000}
WORKFLOW_KEEP_FAILED=${WORKFLOW_KEEP_FAILED:-1}
WORKFLOW_KEEP_DAYS=${WORKFLOW_KEEP_DAYS:-3}
REVIEW_KEEP_DAYS=${REVIEW_KEEP_DAYS:-30}
EOF
if [ $IS_WSL -eq 1 ]; then
  cat >> "$CONF" << EOF
WIN_HOME="$WIN_HOME"
WIN_PY="${WIN_PY:-$WIN_HOME/.venv/Scripts/python.exe}"
EOF
fi
echo "Saved to $CONF"

# ------------------------------------------------------------------
step "Installing packages"
if [ "$PM" = dnf ]; then
  sudo dnf install -y zsh util-linux-user git tmux python3-pip fzf jq gh nano curl bubblewrap gawk
  if [ $IS_WSL -eq 0 ]; then sudo dnf install -y wl-clipboard xclip fontconfig libnotify; fi
else
  sudo apt-get update -qq
  sudo apt-get install -y zsh git tmux python3-venv python3-pip fzf jq nano curl bubblewrap
  if [ $IS_WSL -eq 0 ]; then sudo apt-get install -y wl-clipboard xclip fontconfig libnotify-bin; fi
  sudo apt-get install -y gh || warn "Couldn't install gh from apt. See https://cli.github.com"
fi

# ------------------------------------------------------------------
step "Git"
git config --global init.defaultBranch main
# Windows folders look executable to Linux; don't treat that as a change.
if [ $IS_WSL -eq 1 ]; then git config --global core.fileMode false; fi

# ------------------------------------------------------------------
if [ $IS_WSL -eq 0 ]; then
  step "MesloLGS NF font"
  FONT_DIR="$HOME/.local/share/fonts"; mkdir -p "$FONT_DIR"
  for f in "MesloLGS NF Regular" "MesloLGS NF Bold" "MesloLGS NF Italic" "MesloLGS NF Bold Italic"; do
    [ -f "$FONT_DIR/$f.ttf" ] || curl -fsSL -o "$FONT_DIR/$f.ttf" \
      "https://github.com/romkatv/powerlevel10k-media/raw/master/${f// /%20}.ttf"
  done
  fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
  if gsettings list-schemas 2>/dev/null | grep -qx org.gnome.Ptyxis; then
    gsettings set org.gnome.Ptyxis use-system-font false || true
    gsettings set org.gnome.Ptyxis font-name 'MesloLGS NF 12' || true
    echo "Set the Ptyxis terminal font."
  fi
fi

# ------------------------------------------------------------------
if [ $SHELL_SETUP -eq 1 ]; then
  step "zsh, oh-my-zsh, Powerlevel10k"
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=no sh -c \
      "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi
  ZC="$HOME/.oh-my-zsh/custom"
  [ -d "$ZC/plugins/zsh-autosuggestions" ] || git clone -q https://github.com/zsh-users/zsh-autosuggestions "$ZC/plugins/zsh-autosuggestions"
  [ -d "$ZC/plugins/zsh-syntax-highlighting" ] || git clone -q https://github.com/zsh-users/zsh-syntax-highlighting "$ZC/plugins/zsh-syntax-highlighting"
  [ -d "$ZC/themes/powerlevel10k" ] || git clone -q --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZC/themes/powerlevel10k"

  plugins="git z sudo colored-man-pages"
  if [ "$PM" = dnf ]; then plugins="$plugins dnf"; fi
  plugins="$plugins zsh-autosuggestions zsh-syntax-highlighting"
  sed -i 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' ~/.zshrc
  sed -i "s|^plugins=(.*)|plugins=($plugins)|" ~/.zshrc

  ZSH_BIN=/usr/bin/zsh; [ -x "$ZSH_BIN" ] || ZSH_BIN="$(command -v zsh)"
  [ "$(getent passwd "$USER" | cut -d: -f7)" = "$ZSH_BIN" ] || sudo chsh -s "$ZSH_BIN" "$USER"
fi

step "Shell hooks in ~/.zshrc"
touch ~/.zshrc
grep -q 'agent-grid' ~/.zshrc || backup ~/.zshrc
sed -i '/# >>> agent-grid top >>>/,/# <<< agent-grid top <<</d; /# >>> agent-grid >>>/,/# <<< agent-grid <<</d' ~/.zshrc
tmp=$(mktemp)
printf '%s\n' '# >>> agent-grid top >>>' \
  "[ -f \"$ROOT/shell/top.zsh\" ] && source \"$ROOT/shell/top.zsh\"" \
  '# <<< agent-grid top <<<' > "$tmp"
cat ~/.zshrc >> "$tmp"
printf '%s\n' '# >>> agent-grid >>>' \
  "[ -f \"$ROOT/shell/bottom.zsh\" ] && source \"$ROOT/shell/bottom.zsh\"" \
  '# <<< agent-grid <<<' >> "$tmp"
cat "$tmp" > ~/.zshrc && rm -f "$tmp"

# ------------------------------------------------------------------
step "Python venv (~/.venv)"
[ -d "$HOME/.venv" ] || python3 -m venv "$HOME/.venv"
"$HOME/.venv/bin/pip" install -q --upgrade pip
"$HOME/.venv/bin/pip" install -q pandas openpyxl jupyter

# ------------------------------------------------------------------
step "Claude Code"
if [ -x "$BIN/claude" ] || command -v claude >/dev/null; then
  echo "Already installed."
else
  curl -fsSL https://claude.ai/install.sh | bash
fi

# ------------------------------------------------------------------
step "Linking tools into ~/.local/bin"
# Clean up links to tools that no longer exist in this repo
for l in "$BIN"/*; do
  if [ -L "$l" ] && [[ "$(readlink "$l")" == "$ROOT/bin/"* ]] && [ ! -e "$l" ]; then
    rm "$l"; echo "  removed old $(basename "$l")"
  fi
done
for f in "$ROOT"/bin/*; do
  n=$(basename "$f")
  if [ "$n" = winpy ] && [ $IS_WSL -eq 0 ]; then continue; fi
  chmod +x "$f"
  ln -sfn "$f" "$BIN/$n"
  echo "  $n"
done

# ------------------------------------------------------------------
step "tmux"
touch ~/.tmux.conf
grep -q 'agent-grid' ~/.tmux.conf || backup ~/.tmux.conf
sed -i '/# >>> agent-grid >>>/,/# <<< agent-grid <<</d' ~/.tmux.conf
tmp=$(mktemp)
printf '%s\n' '# >>> agent-grid >>>' "source-file \"$ROOT/config/tmux.conf\"" \
  '# Your own settings go below this block and override the defaults.' \
  '# <<< agent-grid <<<' > "$tmp"
cat ~/.tmux.conf >> "$tmp"
cat "$tmp" > ~/.tmux.conf && rm -f "$tmp"
tmux source-file ~/.tmux.conf 2>/dev/null || true

# ------------------------------------------------------------------
step "Claude Code settings"
mkdir -p ~/.claude ~/chat
S=~/.claude/settings.json
[ -f "$S" ] || echo '{}' > "$S"
if ! jq empty "$S" 2>/dev/null; then
  warn "$S isn't valid JSON, so the agent-grid hooks weren't changed."
else
  backup "$S"; tmp=$(mktemp)
  # One hook script for four events. Old agent-grid entries are replaced, others kept.
  # PreToolUse keeps analysts from changing your checks or reading your hidden checks.
  jq --arg cmd '$HOME/.local/bin/agent-hook' '
    def strip: map(select(([.hooks[]?.command] | any(test("auto-commit|agent-hook"))) | not));
    def entry(t): [{"hooks": [{"type": "command", "command": $cmd, "timeout": t}]}];
    def tools(t): [{"matcher": "Edit|Write|MultiEdit|NotebookEdit|Read|Grep|Glob|Bash",
                    "hooks": [{"type": "command", "command": $cmd, "timeout": t}]}];
    .hooks.Stop             = ((.hooks.Stop // []) | strip) + entry(7200)
    | .hooks.Notification     = ((.hooks.Notification // []) | strip) + entry(30)
    | .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) | strip) + entry(10)
    | .hooks.PreToolUse       = ((.hooks.PreToolUse // []) | strip) + tools(10)
  ' "$S" > "$tmp" && cat "$tmp" > "$S" && rm -f "$tmp"
  echo "Hooks set: status + notifications, checks, manager workflow tests, protecting your checks, and auto-push (spawn --gh)."
  if command -v bwrap >/dev/null && ! bwrap --ro-bind / / --dev /dev --proc /proc true >/dev/null 2>&1; then
    warn "bubblewrap can't run here, so manager tests won't be contained. On Ubuntu 24.04+:"
    warn "  echo 'kernel.apparmor_restrict_unprivileged_userns=0' | sudo tee /etc/sysctl.d/60-agent-grid.conf && sudo sysctl --system"
  fi
  echo "Restart any Claude sessions that were already open so they pick up the hooks."
fi

CM=~/.claude/CLAUDE.md; touch "$CM"
while IFS= read -r line; do [ -n "$line" ] && add_line "$line" "$CM"; done < "$ROOT/config/claude-style.md"
if [ $IS_WSL -eq 1 ]; then
  add_line "- Scripts using win32com or xlwings must run with \`winpy\` (Windows Python), not \`python3\`." "$CM"
fi
add_line "- My screenshots are in $SHOTS. When I say \"latest screenshot\" or \"look at this,\" read the newest image there." "$CM"

# ------------------------------------------------------------------
install_vscode() {
  if [ "$PM" = dnf ]; then
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    printf '%s\n' '[code]' 'name=Visual Studio Code' \
      'baseurl=https://packages.microsoft.com/yumrepos/vscode' 'enabled=1' 'autorefresh=1' \
      'type=rpm-md' 'gpgcheck=1' 'gpgkey=https://packages.microsoft.com/keys/microsoft.asc' \
      | sudo tee /etc/yum.repos.d/vscode.repo >/dev/null
    sudo dnf install -y code
  else
    sudo install -d -m 0755 /etc/apt/keyrings
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor \
      | sudo tee /etc/apt/keyrings/packages.microsoft.gpg >/dev/null
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
      | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    sudo apt-get update -qq && sudo apt-get install -y code
  fi
}

merge_vscode() {   # $1 = settings.json path, $2 = JSON to merge in
  mkdir -p "$(dirname "$1")"
  if [ ! -f "$1" ]; then
    echo "$2" > "$1"; echo "Created $1"
  elif jq empty "$1" 2>/dev/null; then
    backup "$1"
    local t; t=$(mktemp)
    jq -s '.[0] * .[1]' "$1" <(echo "$2") > "$t" && cat "$t" > "$1" && rm -f "$t"
    echo "Merged into $1 (backup saved next to it)"
  else
    warn "Couldn't merge $1 (it has comments). Add these settings by hand:"
    echo "$2"
  fi
}

if [ $VSCODE -eq 1 ]; then
  step "VS Code"
  if [ $IS_WSL -eq 1 ]; then
    DISTRO="${WSL_DISTRO_NAME:-WSL}"
    NEW=$(jq -n --arg d "$DISTRO" '{
      "terminal.integrated.profiles.windows": { ($d): { "path": "C:\\Windows\\System32\\wsl.exe", "args": ["-d", $d] } },
      "terminal.integrated.defaultProfile.windows": $d,
      "terminal.integrated.fontFamily": "MesloLGS NF",
      "terminal.integrated.fontSize": 14,
      "terminal.integrated.lineHeight": 1.2,
      "terminal.integrated.commandsToSkipShell": ["-workbench.action.toggleSidebarVisibility"],
      "python.terminal.activateEnvironment": false
    }')
    merge_vscode "$WIN_HOME/AppData/Roaming/Code/User/settings.json" "$NEW"
    echo "VS Code extensions are installed by windows/setup-windows.ps1."
  else
    command -v code >/dev/null || install_vscode || warn "VS Code install failed. Get it from https://code.visualstudio.com"
    NEW='{
      "terminal.integrated.fontFamily": "MesloLGS NF",
      "terminal.integrated.fontSize": 14,
      "terminal.integrated.lineHeight": 1.2,
      "terminal.integrated.commandsToSkipShell": ["-workbench.action.toggleSidebarVisibility"],
      "python.terminal.activateEnvironment": false
    }'
    merge_vscode "$HOME/.config/Code/User/settings.json" "$NEW"
    if command -v code >/dev/null; then
      for ext in ms-python.python anthropic.claude-code; do
        code --install-extension "$ext" --force >/dev/null 2>&1 && echo "  $ext" || warn "Couldn't install $ext"
      done
    fi
  fi
fi

# ------------------------------------------------------------------
step "Done"
echo "Next:"
if [ $IS_WSL -eq 1 ]; then echo "  1. Open a new terminal."
else echo "  1. Log out and back in (so zsh is your login shell), then open a terminal."; fi
echo '     The Powerlevel10k wizard runs once. Choose "Instant prompt: Off"; it conflicts'
echo '     with tmux autostart. To reuse an old prompt, copy ~/.p10k.zsh from that machine.'
echo "  2. claude             log in once"
echo "  3. spawn -h           see everything spawn can do"
echo
echo "GitHub is off by default. 'spawn --gh' connects the folders you pick and"
echo "auto-pushes Claude's code changes for that launch only."

echo
echo "Settings live in $CONF"
echo "Update later with:  git -C \"$ROOT\" pull && bash \"$ROOT/install.sh\""
echo
step "Checking the setup"
PATH="$BIN:$PATH" "$BIN/spawn" --doctor || true
