# setup-windows.ps1: Windows side of agent-grid.
# Installs the MesloLGS NF font and VS Code extensions, installs WSL with a
# Linux distro (latest Fedora by default), then shows how to run install.sh.
#
# Run from this folder:
#   powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
#   powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1 -Distro Ubuntu
#
# Fonts and extensions install for your user, no admin needed. Installing WSL
# needs an Administrator PowerShell; rerun as admin if that step is skipped.

param([string]$Distro = "")

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Warn($m) { Write-Host "!!  $m" -ForegroundColor Yellow }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ------------------------------------------------------------------
Step "MesloLGS NF font (current user)"
$fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
$regPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
$base = "https://github.com/romkatv/powerlevel10k-media/raw/master"

foreach ($f in "MesloLGS NF Regular", "MesloLGS NF Bold", "MesloLGS NF Italic", "MesloLGS NF Bold Italic") {
    $file = "$f.ttf"
    $dest = Join-Path $fontDir $file
    try {
        if (-not (Test-Path $dest)) {
            Invoke-WebRequest -UseBasicParsing -Uri "$base/$([uri]::EscapeDataString($file))" -OutFile $dest
        }
        New-ItemProperty -Path $regPath -Name "$f (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
        Write-Host "  $f"
    } catch {
        Warn "Couldn't install $f. Download it from https://github.com/romkatv/powerlevel10k#fonts"
    }
}

# ------------------------------------------------------------------
Step "VS Code extensions"
if (Get-Command code -ErrorAction SilentlyContinue) {
    foreach ($ext in "ms-vscode-remote.remote-wsl", "ms-python.python", "anthropic.claude-code") {
        code --install-extension $ext --force | Out-Null
        Write-Host "  $ext"
    }
} else {
    Warn "VS Code not found. Install it from https://code.visualstudio.com, then rerun this script."
}

# ------------------------------------------------------------------
Step "Choosing a Linux distro"
if (-not $Distro) {
    $online = (wsl.exe --list --online 2>$null) -replace "`0", ""
    $fedora = $online | ForEach-Object {
        if ($_ -match '^\s*(FedoraLinux-(\d+))\b') {
            [pscustomobject]@{ Name = $Matches[1]; Ver = [int]$Matches[2] }
        }
    } | Sort-Object Ver -Descending | Select-Object -First 1
    if ($fedora) { $Distro = $fedora.Name } else { $Distro = "Ubuntu" }
}
Write-Host "Using $Distro. To pick another: -Distro <name> (see 'wsl --list --online')."

# ------------------------------------------------------------------
Step "WSL + $Distro"
$installed = (wsl.exe -l -q 2>$null) -replace "`0", "" | Where-Object { $_.Trim() -eq $Distro }

if ($installed) {
    Write-Host "$Distro is already installed."
    wsl.exe --set-default $Distro | Out-Null
} elseif ($isAdmin) {
    wsl.exe --install -d $Distro
    wsl.exe --set-default $Distro 2>$null | Out-Null
    Write-Host "If Windows asks you to restart, restart first."
} else {
    Warn "Skipping WSL: installing it needs an Administrator PowerShell."
    Warn "Rerun this script as admin. Fonts and extensions are already done."
}

# ------------------------------------------------------------------
$repo = Split-Path $PSScriptRoot -Parent
$linuxRepo = $repo
if ($repo -match '^([A-Za-z]):(.*)$') {
    $linuxRepo = "/mnt/" + $Matches[1].ToLower() + ($Matches[2] -replace '\\', '/')
}

Step "Next steps"
Write-Host "  1. Snipping Tool > Settings: turn on 'Automatically save screenshots'."
Write-Host "  2. Windows Terminal > Settings > $Distro > Appearance: Font face 'MesloLGS NF'."
Write-Host "  3. Open $Distro from the Start menu, create your Linux user, then run:"
Write-Host "       cp -r `"$linuxRepo`" ~/agent-grid && bash ~/agent-grid/install.sh" -ForegroundColor Green
Write-Host "     (Copying into your Linux home keeps it fast and lets 'git pull' update it later.)"
