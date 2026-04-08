#Requires -RunAsAdministrator
<#
.SYNOPSIS
    ChristianLempa dotfiles — "Make Windows Terminal look amazing!"
    Full automated setup script — exact replica of dotfiles-6a7e83c3...

    Sections:
      0.  Banner
      1.  WSL2 + Ubuntu-22.04 + Kali-Linux + ArchWSL (yuk7, no-root user prompt)
      2.  Winget packages
      3.  Nerd Fonts (Hack + JetBrainsMono + Anonymice)
      4.  Windows Terminal settings.json  (emoji tab icons — no PNG files needed)
      5.  Starship config (Windows)
      6.  PowerShell profile
      7.  WSL dotfiles (.zshrc / .bashrc / .zshenv / starship-linux.toml / neofetch)
      8.  Files app theme (TheDigitalLife.xaml)
      9.  Rainmeter xcad skin
      10. Windows 11 Dark Mode
      11. Mr. Robot wallpaper (ChristianLempa/hackbox)
      12. PowerShell modules
      13. Git globals
      14. Explorer tweaks
      15. Restart Explorer

.NOTES
    Run from an elevated PowerShell 7 session:
        Set-ExecutionPolicy Bypass -Scope Process -Force
        .\Install-Dotfiles.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ─────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────
function Write-Step { param($msg) Write-Host "`n[ >> ] $msg" -ForegroundColor Cyan }
function Write-OK   { param($msg) Write-Host "  [OK] $msg"   -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  [!!] $msg"   -ForegroundColor Yellow }

function Ensure-Dir {
    param($path)
    if (!(Test-Path $path)) { New-Item -ItemType Directory -Force -Path $path | Out-Null }
}

function Install-WingetPkg {
    param([string]$id, [string]$label = $id)
    Write-Host "      $label ..." -NoNewline
    winget install --id $id --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
        Write-Host " done" -ForegroundColor Green
    } else {
        Write-Host " FAILED (exit $LASTEXITCODE)" -ForegroundColor Yellow
    }
}

# ─────────────────────────────────────────────
#  0. BANNER
# ─────────────────────────────────────────────
Clear-Host
Write-Host @"

  ████████╗███████╗██████╗ ███╗   ███╗██╗███╗   ██╗ █████╗ ██╗
  ╚══██╔══╝██╔════╝██╔══██╗████╗ ████║██║████╗  ██║██╔══██╗██║
     ██║   █████╗  ██████╔╝██╔████╔██║██║██╔██╗ ██║███████║██║
     ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║██║╚██╗██║██╔══██║██║
     ██║   ███████╗██║  ██║██║ ╚═╝ ██║██║██║ ╚████║██║  ██║███████╗
     ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝
  ChristianLempa dotfiles — Make Windows Terminal look amazing!
"@ -ForegroundColor Magenta

# ─────────────────────────────────────────────
#  1. WSL2 + DISTROS
#     Ubuntu-22.04  →  wsl --install -d Ubuntu-22.04
#     kali-linux    →  wsl --install -d kali-linux
#     ArchWSL       →  yuk7/ArchWSL (no default root — prompts for YOUR user+pass)
# ─────────────────────────────────────────────
Write-Step "Setting up WSL2 and distros"

# Enable required Windows features
Write-Host "      Enabling WSL features ..." -NoNewline
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart 2>&1 | Out-Null
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart 2>&1 | Out-Null
Write-Host " done" -ForegroundColor Green

# WSL2 as default
wsl --set-default-version 2 2>&1 | Out-Null
Write-OK "WSL default version → 2"

# Update WSL kernel
Write-Host "      Updating WSL kernel ..." -NoNewline
wsl --update 2>&1 | Out-Null
Write-Host " done" -ForegroundColor Green

# ── Ubuntu-22.04 ──────────────────────────────
$wslList = wsl --list --quiet 2>&1
if (-not ($wslList -match "Ubuntu-22.04")) {
    Write-Host ""
    Write-Host "  Installing Ubuntu-22.04 ..." -ForegroundColor Yellow
    Write-Host "  You will be prompted to enter a USERNAME and PASSWORD." -ForegroundColor Yellow
    wsl --install -d Ubuntu-22.04
    Write-OK "Ubuntu-22.04 installed"
} else {
    Write-Host "      Ubuntu-22.04 already installed" -ForegroundColor DarkGray
}

# ── Kali Linux ────────────────────────────────
$wslList = wsl --list --quiet 2>&1
if (-not ($wslList -match "kali-linux")) {
    Write-Host ""
    Write-Host "  Installing kali-linux ..." -ForegroundColor Yellow
    Write-Host "  You will be prompted to enter a USERNAME and PASSWORD." -ForegroundColor Yellow
    wsl --install -d kali-linux
    Write-OK "kali-linux installed"
} else {
    Write-Host "      kali-linux already installed" -ForegroundColor DarkGray
}

# ── ArchWSL (yuk7) — no root, user/pass prompt on first launch ─
$wslList = wsl --list --quiet 2>&1
if (-not ($wslList -match "^Arch")) {
    Write-Step "Installing ArchWSL (yuk7/ArchWSL)"
    Write-Host "  ArchWSL does NOT log in as root by default." -ForegroundColor Yellow
    Write-Host "  On first launch you will choose your own USERNAME + PASSWORD." -ForegroundColor Yellow

    $archDir = "$HOME\ArchWSL"
    Ensure-Dir $archDir
    $archZip = "$archDir\Arch.zip"
    $archExe = "$archDir\Arch.exe"

    try {
        Write-Host "      Fetching latest ArchWSL release from GitHub ..." -NoNewline
        $release  = Invoke-RestMethod "https://api.github.com/repos/yuk7/ArchWSL/releases/latest" -UseBasicParsing
        $asset    = $release.assets | Where-Object { $_.name -eq "Arch.zip" } | Select-Object -First 1
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $archZip -UseBasicParsing
        Write-Host " done" -ForegroundColor Green

        Write-Host "      Extracting ..." -NoNewline
        Expand-Archive -Path $archZip -DestinationPath $archDir -Force
        Write-Host " done" -ForegroundColor Green

        Write-Host ""
        Write-Host "  ┌──────────────────────────────────────────────────────────────┐" -ForegroundColor Cyan
        Write-Host "  │  ArchWSL first-time setup:                                   │" -ForegroundColor Cyan
        Write-Host "  │  A new window will open. Enter your desired username +        │" -ForegroundColor Cyan
        Write-Host "  │  password when prompted, then close the window to continue.   │" -ForegroundColor Cyan
        Write-Host "  └──────────────────────────────────────────────────────────────┘" -ForegroundColor Cyan
        Write-Host ""

        Start-Process -FilePath $archExe -WorkingDirectory $archDir -Wait

        Write-OK "ArchWSL installed and registered → $archDir"
        Write-Host "      Windows Terminal profile uses: wsl.exe -d Arch" -ForegroundColor DarkGray
        Write-Host "      Your chosen username will be the default login." -ForegroundColor DarkGray

    } catch {
        Write-Warn "ArchWSL download failed: $_"
        Write-Warn "Download manually: https://github.com/yuk7/ArchWSL/releases/latest"
        Write-Warn "Extract Arch.zip to $archDir and run Arch.exe"
    }
} else {
    Write-Host "      Arch already installed" -ForegroundColor DarkGray
}

Write-OK "WSL distros ready"

# ─────────────────────────────────────────────
#  2. WINGET PACKAGES
# ─────────────────────────────────────────────
Write-Step "Installing packages via winget"

$packages = @(
    @{ id = "Microsoft.PowerShell";         label = "PowerShell 7"        }
    @{ id = "Microsoft.WindowsTerminal";    label = "Windows Terminal"    }
    @{ id = "Starship.Starship";            label = "Starship prompt"     }
    @{ id = "Git.Git";                      label = "Git"                 }
    @{ id = "GitHub.GitHubDesktop";         label = "GitHub Desktop"      }
    @{ id = "Microsoft.VisualStudioCode";   label = "VS Code"             }
    @{ id = "Neovim.Neovim";               label = "Neovim"              }
    @{ id = "Kubernetes.kubectl";           label = "kubectl"             }
    @{ id = "Helm.Helm";                    label = "Helm"                }
    @{ id = "Docker.DockerDesktop";         label = "Docker Desktop"      }
    @{ id = "eza-community.eza";            label = "eza (better ls)"     }
    @{ id = "sharkdp.bat";                  label = "bat"                 }
    @{ id = "BurntSushi.ripgrep.MSVC";      label = "ripgrep"             }
    @{ id = "ajeetdsouza.zoxide";           label = "zoxide"              }
    @{ id = "Rainmeter.Rainmeter";          label = "Rainmeter"           }
    @{ id = "Python.Python.3.11";           label = "Python 3.11"         }
    @{ id = "OpenJS.NodeJS.LTS";            label = "Node.js LTS"         }
)

foreach ($pkg in $packages) { Install-WingetPkg -id $pkg.id -label $pkg.label }
Write-OK "Packages installed"

# ─────────────────────────────────────────────
#  3. NERD FONTS
#     Hack Nerd Font      — Windows Terminal default (settings.json)
#     JetBrainsMono       — PowerShell profile (video screenshot)
#     Anonymice Nerd Font — Rainmeter xcad skin (Variables.inc)
# ─────────────────────────────────────────────
Write-Step "Installing Nerd Fonts"

$fontsDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
Ensure-Dir $fontsDir
$regFontsPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"

$fontUrls = @{
    "HackNerdFont-Regular.ttf"          = "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Hack/Regular/HackNerdFont-Regular.ttf"
    "HackNerdFont-Bold.ttf"             = "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Hack/Bold/HackNerdFont-Bold.ttf"
    "HackNerdFont-Italic.ttf"           = "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Hack/Italic/HackNerdFont-Italic.ttf"
    "HackNerdFont-BoldItalic.ttf"       = "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/Hack/BoldItalic/HackNerdFont-BoldItalic.ttf"
    "JetBrainsMonoNerdFont-Regular.ttf" = "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/JetBrainsMono/Ligatures/Regular/JetBrainsMonoNerdFont-Regular.ttf"
    "JetBrainsMonoNerdFont-Medium.ttf"  = "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/JetBrainsMono/Ligatures/Medium/JetBrainsMonoNerdFont-Medium.ttf"
    "JetBrainsMonoNerdFont-Bold.ttf"    = "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/JetBrainsMono/Ligatures/Bold/JetBrainsMonoNerdFont-Bold.ttf"
    "AnonymiceNerdFont-Regular.ttf"     = "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/AnonymousPro/Regular/AnonymiceNerdFont-Regular.ttf"
    "AnonymiceNerdFont-Bold.ttf"        = "https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/AnonymousPro/Bold/AnonymiceNerdFont-Bold.ttf"
}

foreach ($font in $fontUrls.GetEnumerator()) {
    $dest = Join-Path $fontsDir $font.Key
    if (!(Test-Path $dest)) {
        Write-Host "      $($font.Key) ..." -NoNewline
        try {
            Invoke-WebRequest -Uri $font.Value -OutFile $dest -UseBasicParsing
            $fontName = [System.IO.Path]::GetFileNameWithoutExtension($font.Key) + " (TrueType)"
            Set-ItemProperty -Path $regFontsPath -Name $fontName -Value $dest -Force
            Write-Host " done" -ForegroundColor Green
        } catch { Write-Host " FAILED: $_" -ForegroundColor Yellow }
    } else {
        Write-Host "      $($font.Key) already present" -ForegroundColor DarkGray
    }
}
Write-OK "Fonts installed"

# ─────────────────────────────────────────────
#  4. WINDOWS TERMINAL  settings.json
#     Tab icons use Unicode emoji — no PNG files or downloads needed.
#     Icons:
#       PowerShell  →  󰨊  (Nerd Font ps glyph, falls back to 💙)
#       Ubuntu      →  󰕈  (Nerd Font ubuntu glyph, falls back to 🟠)
#       Kali        →  󱄛  (Nerd Font kali glyph, falls back to 🐉)
#       Arch        →  󰣇  (Nerd Font arch glyph, falls back to 🔵)
#       Commandline →  󰞷  (Nerd Font cmd glyph, falls back to 🖥️)
#       Azure       →  󰠅  (Nerd Font azure glyph, falls back to ☁️)
#     Color scheme: xcad (your original colors, kept exactly)
#     All xcad_* colour schemes included
# ─────────────────────────────────────────────
Write-Step "Deploying Windows Terminal settings.json"

$wtSettingsDir = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
Ensure-Dir $wtSettingsDir

$wtSettings = @'
{
    "$help": "https://aka.ms/terminal-documentation",
    "$schema": "https://aka.ms/terminal-profiles-schema",
    "actions": [],
    "alwaysShowNotificationIcon": false,
    "defaultProfile": "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
    "firstWindowPreference": "defaultProfile",
    "profiles": {
        "defaults": {
            "colorScheme": "xcad",
            "cursorShape": "filledBox",
            "font": {
                "face": "Hack Nerd Font",
                "size": 14
            },
            "historySize": 12000,
            "intenseTextStyle": "bright",
            "opacity": 95,
            "padding": "8",
            "scrollbarState": "visible",
            "useAcrylic": false
        },
        "list": [
            {
                "commandline": "C:\\Program Files\\PowerShell\\7\\pwsh.exe --NoLogo",
                "elevate": false,
                "guid": "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
                "hidden": false,
                "icon": "\udb80\ude0a",
                "name": "PowerShell",
                "source": "Windows.Terminal.PowershellCore"
            },
            {
                "guid": "{07b52e3e-de2c-5db4-bd2d-ba144ed6c273}",
                "hidden": false,
                "icon": "\udb80\udd48",
                "name": "Ubuntu Linux",
                "source": "Windows.Terminal.Wsl",
                "startingDirectory": "\\\\wsl$\\Ubuntu-20.04\\home\\xcad"
            },
            {
                "guid": "{46ca431a-3a87-5fb3-83cd-11ececc031d2}",
                "hidden": false,
                "icon": "\udbc1\udd1b",
                "name": "Kali Linux",
                "source": "Windows.Terminal.Wsl",
                "startingDirectory": "\\\\wsl.localhost\\kali-linux\\home\\xcad"
            },
            {
                "commandline": "wsl.exe -d Arch",
                "guid": "{a5a97cb8-8961-5535-816d-772efe0c6a3f}",
                "hidden": false,
                "icon": "\udb80\udec7",
                "name": "Arch Linux",
                "startingDirectory": "~"
            },
            {
                "commandline": "cmd.exe",
                "guid": "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}",
                "hidden": false,
                "icon": "\udb80\uddb7",
                "name": "Commandline"
            },
            {
                "guid": "{b453ae62-4e3d-5e58-b989-0a998ec441b8}",
                "hidden": true,
                "icon": "\udb80\ude05",
                "name": "Azure Cloud Shell",
                "source": "Windows.Terminal.Azure"
            }
        ]
    },
    "schemes": [
        {
            "background": "#1A1A1A",
            "black": "#121212",
            "blue": "#2B4FFF",
            "brightBlack": "#666666",
            "brightBlue": "#5C78FF",
            "brightCyan": "#5AC8FF",
            "brightGreen": "#905AFF",
            "brightPurple": "#5EA2FF",
            "brightRed": "#BA5AFF",
            "brightWhite": "#FFFFFF",
            "brightYellow": "#685AFF",
            "cursorColor": "#FFFFFF",
            "cyan": "#28B9FF",
            "foreground": "#F1F1F1",
            "green": "#7129FF",
            "name": "xcad",
            "purple": "#2883FF",
            "red": "#A52AFF",
            "selectionBackground": "#FFFFFF",
            "white": "#F1F1F1",
            "yellow": "#3D2AFF"
        },
        {
            "background": "#080808", "black": "#0A0A0A", "blue": "#0037DA",
            "brightBlack": "#767676", "brightBlue": "#3B78FF", "brightCyan": "#61D6D6",
            "brightGreen": "#16C60C", "brightPurple": "#B4009E", "brightRed": "#E74856",
            "brightWhite": "#F2F2F2", "brightYellow": "#F9F1A5", "cursorColor": "#FFFFFF",
            "cyan": "#3A96DD", "foreground": "#CCCCCC", "green": "#13A10E",
            "name": "Campbell", "purple": "#881798", "red": "#C50F1F",
            "selectionBackground": "#FFFFFF", "white": "#CCCCCC", "yellow": "#C19C00"
        },
        {
            "background": "#012456", "black": "#0C0C0C", "blue": "#0037DA",
            "brightBlack": "#767676", "brightBlue": "#3B78FF", "brightCyan": "#61D6D6",
            "brightGreen": "#16C60C", "brightPurple": "#B4009E", "brightRed": "#E74856",
            "brightWhite": "#F2F2F2", "brightYellow": "#F9F1A5", "cursorColor": "#FFFFFF",
            "cyan": "#3A96DD", "foreground": "#CCCCCC", "green": "#13A10E",
            "name": "Campbell Powershell", "purple": "#881798", "red": "#C50F1F",
            "selectionBackground": "#FFFFFF", "white": "#CCCCCC", "yellow": "#C19C00"
        },
        {
            "background": "#282C34", "black": "#282C34", "blue": "#61AFEF",
            "brightBlack": "#5A6374", "brightBlue": "#61AFEF", "brightCyan": "#56B6C2",
            "brightGreen": "#98C379", "brightPurple": "#C678DD", "brightRed": "#E06C75",
            "brightWhite": "#DCDFE4", "brightYellow": "#E5C07B", "cursorColor": "#FFFFFF",
            "cyan": "#56B6C2", "foreground": "#DCDFE4", "green": "#98C379",
            "name": "One Half Dark", "purple": "#C678DD", "red": "#E06C75",
            "selectionBackground": "#FFFFFF", "white": "#DCDFE4", "yellow": "#E5C07B"
        },
        {
            "background": "#FAFAFA", "black": "#383A42", "blue": "#0184BC",
            "brightBlack": "#4F525D", "brightBlue": "#61AFEF", "brightCyan": "#56B5C1",
            "brightGreen": "#98C379", "brightPurple": "#C577DD", "brightRed": "#DF6C75",
            "brightWhite": "#FFFFFF", "brightYellow": "#E4C07A", "cursorColor": "#4F525D",
            "cyan": "#0997B3", "foreground": "#383A42", "green": "#50A14F",
            "name": "One Half Light", "purple": "#A626A4", "red": "#E45649",
            "selectionBackground": "#FFFFFF", "white": "#FAFAFA", "yellow": "#C18301"
        },
        {
            "background": "#002B36", "black": "#002B36", "blue": "#268BD2",
            "brightBlack": "#073642", "brightBlue": "#839496", "brightCyan": "#93A1A1",
            "brightGreen": "#586E75", "brightPurple": "#6C71C4", "brightRed": "#CB4B16",
            "brightWhite": "#FDF6E3", "brightYellow": "#657B83", "cursorColor": "#FFFFFF",
            "cyan": "#2AA198", "foreground": "#839496", "green": "#859900",
            "name": "Solarized Dark", "purple": "#D33682", "red": "#DC322F",
            "selectionBackground": "#FFFFFF", "white": "#EEE8D5", "yellow": "#B58900"
        },
        {
            "background": "#FDF6E3", "black": "#002B36", "blue": "#268BD2",
            "brightBlack": "#073642", "brightBlue": "#839496", "brightCyan": "#93A1A1",
            "brightGreen": "#586E75", "brightPurple": "#6C71C4", "brightRed": "#CB4B16",
            "brightWhite": "#FDF6E3", "brightYellow": "#657B83", "cursorColor": "#002B36",
            "cyan": "#2AA198", "foreground": "#657B83", "green": "#859900",
            "name": "Solarized Light", "purple": "#D33682", "red": "#DC322F",
            "selectionBackground": "#FFFFFF", "white": "#EEE8D5", "yellow": "#B58900"
        },
        {
            "background": "#000000", "black": "#000000", "blue": "#3465A4",
            "brightBlack": "#555753", "brightBlue": "#729FCF", "brightCyan": "#34E2E2",
            "brightGreen": "#8AE234", "brightPurple": "#AD7FA8", "brightRed": "#EF2929",
            "brightWhite": "#EEEEEC", "brightYellow": "#FCE94F", "cursorColor": "#FFFFFF",
            "cyan": "#06989A", "foreground": "#D3D7CF", "green": "#4E9A06",
            "name": "Tango Dark", "purple": "#75507B", "red": "#CC0000",
            "selectionBackground": "#FFFFFF", "white": "#D3D7CF", "yellow": "#C4A000"
        },
        {
            "background": "#FFFFFF", "black": "#000000", "blue": "#3465A4",
            "brightBlack": "#555753", "brightBlue": "#729FCF", "brightCyan": "#34E2E2",
            "brightGreen": "#8AE234", "brightPurple": "#AD7FA8", "brightRed": "#EF2929",
            "brightWhite": "#EEEEEC", "brightYellow": "#FCE94F", "cursorColor": "#000000",
            "cyan": "#06989A", "foreground": "#555753", "green": "#4E9A06",
            "name": "Tango Light", "purple": "#75507B", "red": "#CC0000",
            "selectionBackground": "#FFFFFF", "white": "#D3D7CF", "yellow": "#C4A000"
        },
        {
            "background": "#000000", "black": "#000000", "blue": "#000080",
            "brightBlack": "#808080", "brightBlue": "#0000FF", "brightCyan": "#00FFFF",
            "brightGreen": "#00FF00", "brightPurple": "#FF00FF", "brightRed": "#FF0000",
            "brightWhite": "#FFFFFF", "brightYellow": "#FFFF00", "cursorColor": "#FFFFFF",
            "cyan": "#008080", "foreground": "#C0C0C0", "green": "#008000",
            "name": "Vintage", "purple": "#800080", "red": "#800000",
            "selectionBackground": "#FFFFFF", "white": "#C0C0C0", "yellow": "#808000"
        },
        {
            "background": "#111927", "black": "#000000", "blue": "#004CFF",
            "brightBlack": "#666666", "brightBlue": "#5CB2FF", "brightCyan": "#5CECC6",
            "brightGreen": "#C5F467", "brightPurple": "#AE81FF", "brightRed": "#FF8484",
            "brightWhite": "#FFFFFF", "brightYellow": "#FFCC5C", "cursorColor": "#FFFFFF",
            "cyan": "#2EE7B6", "foreground": "#D4D4D4", "green": "#9FEF00",
            "name": "xcad_hackthebox", "purple": "#BC3FBC", "red": "#FF3E3E",
            "selectionBackground": "#FFFFFF", "white": "#FFFFFF", "yellow": "#FFAF00"
        },
        {
            "background": "#1A1A1A", "black": "#121212", "blue": "#2B4FFF",
            "brightBlack": "#2F2F2F", "brightBlue": "#5C78FF", "brightCyan": "#5AC8FF",
            "brightGreen": "#905AFF", "brightPurple": "#5EA2FF", "brightRed": "#BA5AFF",
            "brightWhite": "#FFFFFF", "brightYellow": "#685AFF", "cursorColor": "#FFFFFF",
            "cyan": "#28B9FF", "foreground": "#F1F1F1", "green": "#7129FF",
            "name": "xcad_tdl", "purple": "#2883FF", "red": "#A52AFF",
            "selectionBackground": "#FFFFFF", "white": "#F1F1F1", "yellow": "#3D2AFF"
        },
        {
            "background": "#0F0F0F", "black": "#000000", "blue": "#2878FF",
            "brightBlack": "#2F2F2F", "brightBlue": "#5E99FF", "brightCyan": "#5AD6FF",
            "brightGreen": "#FFB15A", "brightPurple": "#935CFF", "brightRed": "#FF755A",
            "brightWhite": "#FFFFFF", "brightYellow": "#FFD25A", "cursorColor": "#FFFFFF",
            "cyan": "#28C8FF", "foreground": "#F1F1F1", "green": "#FF9A28",
            "name": "xcad_tdl_colorful", "purple": "#732BFF", "red": "#FF4C27",
            "selectionBackground": "#FFFFFF", "white": "#F1F1F1", "yellow": "#FFC72A"
        },
        {
            "background": "#0F0F0F", "black": "#000000", "blue": "#184AE8",
            "brightBlack": "#5F5F5F", "brightBlue": "#4771F5", "brightCyan": "#31C1FF",
            "brightGreen": "#FFD631", "brightPurple": "#7631FF", "brightRed": "#FF3190",
            "brightWhite": "#FFFFFF", "brightYellow": "#FF9731", "cursorColor": "#FFFFFF",
            "cyan": "#008DCB", "foreground": "#D9D9D9", "green": "#CBA300",
            "name": "xcad_tdl_old", "purple": "#4300CB", "red": "#CB005F",
            "selectionBackground": "#FFFFFF", "white": "#CFCFCF", "yellow": "#CB6600"
        },
        {
            "background": "#282C34", "black": "#000000", "blue": "#007ACC",
            "brightBlack": "#75715E", "brightBlue": "#11A8CD", "brightCyan": "#11A8CD",
            "brightGreen": "#0DBC79", "brightPurple": "#AE81FF", "brightRed": "#DD6B65",
            "brightWhite": "#F8F8F2", "brightYellow": "#E6DB74", "cursorColor": "#FFFFFF",
            "cyan": "#11A8CD", "foreground": "#D4D4D4", "green": "#0DBC79",
            "name": "xcad_vscode", "purple": "#BC3FBC", "red": "#F4423A",
            "selectionBackground": "#FFFFFF", "white": "#F8F8F2", "yellow": "#E5E510"
        }
    ],
    "showTabsInTitlebar": true,
    "tabSwitcherMode": "inOrder",
    "useAcrylicInTabRow": true
}
'@

$wtSettings | Set-Content -Path "$wtSettingsDir\settings.json" -Encoding UTF8 -Force
Write-OK "Windows Terminal settings.json deployed (emoji tab icons — no PNGs needed)"

# ─────────────────────────────────────────────
#  5. STARSHIP CONFIG  (Windows)
# ─────────────────────────────────────────────
Write-Step "Deploying Starship config (Windows)"

$starshipDir = "$HOME\.starship"
Ensure-Dir $starshipDir

$starshipToml = @'
# ~/.config/starship.toml

# Inserts a blank line between shell prompts
add_newline = true

# Change the default prompt format
format = """\
[╭╴](238)$env_var\
$all[╰─](238)$character"""

# Change the default prompt characters
[character]
success_symbol = "[](238)"
error_symbol = "[](238)"

# Shows an icon based on the distribution or os (set via STARSHIP_DISTRO env var in shell rc)
[env_var.STARSHIP_DISTRO]
format = '[$env_value](bold white)'
variable = "STARSHIP_DISTRO"
disabled = false

# Shows the username
[username]
style_user = "white bold"
style_root = "black bold"
format = "[$user]($style) "
disabled = true
show_always = false

[directory]
truncation_length = 3
truncation_symbol = "…/"
home_symbol = " ~"
read_only_style = "197"
read_only = "  "
format = "at [$path]($style)[$read_only]($read_only_style) "

[git_branch]
symbol = " "
format = "on [$symbol$branch]($style) "
truncation_length = 4
truncation_symbol = "…/"
style = "bold green"

[git_status]
format = '[\\($all_status$ahead_behind\\)]($style) '
style = "bold green"
conflicted = "🏳"
up_to_date = " "
untracked = " "
ahead = "⇡${count}"
diverged = "⇕⇡${ahead_count}⇣${behind_count}"
behind = "⇣${count}"
stashed = " "
modified = " "
staged = '[++\\($count\\)](green)'
renamed = "襁 "
deleted = " "

[terraform]
format = "via [ terraform $version]($style) 壟 [$workspace]($style) "

[vagrant]
format = "via [ vagrant $version]($style) "

[docker_context]
format = "via [ $context](bold blue) "

[helm]
format = "via [ $version](bold purple) "

[python]
symbol = " "
python_binary = "python3"

[nodejs]
format = "via [ $version](bold green) "
disabled = true

[ruby]
format = "via [ $version]($style) "

[kubernetes]
format = 'on [ $context\\($namespace\\)](bold purple) '
disabled = false

[kubernetes.context_aliases]
"clcreative-k8s-staging" = "cl-k8s-staging"
"clcreative-k8s-production" = "cl-k8s-prod"
'@

$starshipToml | Set-Content -Path "$starshipDir\starship.toml" -Encoding UTF8 -Force
Write-OK "Starship config → $starshipDir\starship.toml"

# ─────────────────────────────────────────────
#  6. POWERSHELL PROFILE
# ─────────────────────────────────────────────
Write-Step "Deploying PowerShell profile"

$ps7ProfileDir = "$HOME\Documents\PowerShell"
Ensure-Dir $ps7ProfileDir
Ensure-Dir (Split-Path $PROFILE -Parent)

$psProfile = @'
# ─────────────────────────────────────────────────────────────
#  ChristianLempa dotfiles — PowerShell Profile
# ─────────────────────────────────────────────────────────────

# Aliases
New-Alias k kubectl -Force -ErrorAction SilentlyContinue
Remove-Alias h -Force -ErrorAction SilentlyContinue
New-Alias h helm    -Force -ErrorAction SilentlyContinue
New-Alias g goto    -Force -ErrorAction SilentlyContinue

# goto helper
function goto {
    param($location)
    Switch ($location) {
        "pr" { Set-Location -Path "$HOME/projects"              }
        "bp" { Set-Location -Path "$HOME/projects/boilerplates" }
        "cs" { Set-Location -Path "$HOME/projects/cheat-sheets" }
        default { echo "Invalid location"                       }
    }
}

# kubectl namespace switcher
function kn {
    param($namespace)
    if ($namespace -in "default","d") {
        kubectl config set-context --current --namespace=default
    } else {
        kubectl config set-context --current --namespace=$namespace
    }
}

# Starship — exact lines from dotfiles (Windows logo glyph + username)
$ENV:STARSHIP_CONFIG = "$HOME\.starship\starship.toml"
$ENV:STARSHIP_DISTRO = " $env:USERNAME"
Invoke-Expression (&starship init powershell)

# zoxide (smarter cd)
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# eza — mirrors the .zshrc aliases
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function ls { eza --icons --group-directories-first @args }
    function ll { eza --icons --group-directories-first -l @args }
    function la { eza --icons --group-directories-first -la @args }
    function lt { eza --icons --tree --level=2 @args }
} else {
    function ll { Get-ChildItem -Force @args }
}

function which  ($cmd) { (Get-Command $cmd -ErrorAction SilentlyContinue).Source }
function reload ()     { & $PROFILE }
'@

$psProfile | Set-Content -Path $PROFILE -Encoding UTF8 -Force
$psProfile | Set-Content -Path "$ps7ProfileDir\Microsoft.PowerShell_profile.ps1" -Encoding UTF8 -Force
Write-OK "PowerShell profile deployed"

# ─────────────────────────────────────────────
#  7. WSL DOTFILES
# ─────────────────────────────────────────────
Write-Step "Writing WSL dotfiles to $HOME\.wsl-dotfiles\"

$wslDir = "$HOME\.wsl-dotfiles"
Ensure-Dir "$wslDir\.config\neofetch"

# ── .zshrc ────────────────────────────────────
$zshrc = @'
# Goto
[[ -s "/usr/local/share/goto.sh" ]] && source /usr/local/share/goto.sh

# NVM lazy load
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"
  alias nvm='unalias nvm node npm && . "$NVM_DIR"/nvm.sh && nvm'
  alias node='unalias nvm node npm && . "$NVM_DIR"/nvm.sh && node'
  alias npm='unalias nvm node npm && . "$NVM_DIR"/nvm.sh && npm'
fi

# Fix Interop Error in VSCode terminal when using WSL2
fix_wsl2_interop() {
    for i in $(pstree -np -s $$ | grep -o -E '[0-9]+'); do
        if [[ -e "/run/WSL/${i}_interop" ]]; then
            export WSL_INTEROP=/run/WSL/${i}_interop
        fi
    done
}

# Kubectl
alias k="kubectl"
alias h="helm"

kn() {
    if [ "$1" != "" ]; then
        kubectl config set-context --current --namespace=$1
    else
        echo -e "\e[1;31m Error, please provide a valid Namespace\e[0m"
    fi
}

knd() {
    kubectl config set-context --current --namespace=default
}

ku() {
    kubectl config unset current-context
}

# Colormap
function colormap() {
  for i in {0..255}; do print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f " ${${(M)$((i%6)):#3}:+$'\n'}; done
}

# Aliases
alias ls="eza --icons --group-directories-first"
alias ll="eza --icons --group-directories-first -l"
alias g="goto"
alias grep='grep --color'

alias cbp="code /home/xcad/obsidianvault/boilerplates"
alias cpr="code /home/xcad/obsidianvault/projects"

# Distro detection
LFILE="/etc/*-release"
MFILE="/System/Library/CoreServices/SystemVersion.plist"
if [[ -f $LFILE ]]; then
  _distro=$(awk '/^ID=/' /etc/*-release | awk -F'=' '{ print tolower($2) }')
elif [[ -f $MFILE ]]; then
  _distro="macos"
fi

case $_distro in
    *kali*)                  ICON="ﴣ";;
    *arch*)                  ICON="";;
    *debian*)                ICON="";;
    *raspbian*)              ICON="";;
    *ubuntu*)                ICON="";;
    *elementary*)            ICON="";;
    *fedora*)                ICON="";;
    *coreos*)                ICON="";;
    *gentoo*)                ICON="";;
    *mageia*)                ICON="";;
    *centos*)                ICON="";;
    *opensuse*|*tumbleweed*) ICON="";;
    *sabayon*)               ICON="";;
    *slackware*)             ICON="";;
    *linuxmint*)             ICON="";;
    *alpine*)                ICON="";;
    *aosc*)                  ICON="";;
    *nixos*)                 ICON="";;
    *devuan*)                ICON="";;
    *manjaro*)               ICON="";;
    *rhel*)                  ICON="";;
    *macos*)                 ICON="";;
    *)                       ICON="";;
esac

export STARSHIP_DISTRO="$ICON"

eval "$(starship init zsh)"
'@
$zshrc | Set-Content -Path "$wslDir\.zshrc" -Encoding UTF8 -Force

# ── .bashrc ───────────────────────────────────
$bashrc = @'
_distro=$(awk '/^ID=/' /etc/*-release | awk -F'=' '{ print tolower($2) }')

case $_distro in
    *kali*)                  ICON="ﴣ";;
    *arch*)                  ICON="";;
    *debian*)                ICON="";;
    *raspbian*)              ICON="";;
    *ubuntu*)                ICON="";;
    *elementary*)            ICON="";;
    *fedora*)                ICON="";;
    *coreos*)                ICON="";;
    *gentoo*)                ICON="";;
    *mageia*)                ICON="";;
    *centos*)                ICON="";;
    *opensuse*|*tumbleweed*) ICON="";;
    *sabayon*)               ICON="";;
    *slackware*)             ICON="";;
    *linuxmint*)             ICON="";;
    *alpine*)                ICON="";;
    *aosc*)                  ICON="";;
    *nixos*)                 ICON="";;
    *devuan*)                ICON="";;
    *manjaro*)               ICON="";;
    *rhel*)                  ICON="";;
    *macos*)                 ICON="";;
    *)                       ICON="";;
esac

export STARSHIP_DISTRO="$ICON "
export STARSHIP_CONFIG=~/.starship/starship.toml
eval "$(starship init bash)"

export PATH="$PATH:/home/ansible/.local/bin"
export PATH="$PATH:$HOME/.cargo/bin"

HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend
shopt -s checkwinsize

if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi

if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
'@
$bashrc | Set-Content -Path "$wslDir\.bashrc" -Encoding UTF8 -Force

# ── .zshenv ───────────────────────────────────
$zshenv = @'
export PATH=$PATH:$HOME/.local/bin:$HOME/.cargo/bin
export NVM_DIR="$HOME/.nvm"
export VAGRANT_DEFAULT_PROVIDER="hyperv"
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
'@
$zshenv | Set-Content -Path "$wslDir\.zshenv" -Encoding UTF8 -Force

# ── starship-linux.toml (username ENABLED for WSL) ──────────
$starshipLinux = @'
# ~/.starship/starship.toml  — Linux / WSL variant

add_newline = true
command_timeout = 1000

format = """\
[╭╴](238)$env_var\
$all[╰─](238)$character"""

[character]
success_symbol = "[](238)"
error_symbol = "[](238)"

[env_var.STARSHIP_DISTRO]
format = '[$env_value](bold white) '
variable = "STARSHIP_DISTRO"
disabled = false

[username]
style_user = "white bold"
style_root = "black bold"
format = "[$user]($style) "
disabled = false
show_always = true

[directory]
truncation_length = 3
truncation_symbol = "…/"
home_symbol = " ~"
read_only_style = "197"
read_only = "  "
format = "at [$path]($style)[$read_only]($read_only_style) "

[git_branch]
symbol = " "
format = "on [$symbol$branch]($style) "
truncation_length = 4
truncation_symbol = "…/"
style = "bold green"

[git_status]
format = '[\\($all_status$ahead_behind\\)]($style) '
style = "bold green"
conflicted = "🏳"
up_to_date = " "
untracked = " "
ahead = "⇡${count}"
diverged = "⇕⇡${ahead_count}⇣${behind_count}"
behind = "⇣${count}"
stashed = " "
modified = " "
staged = '[++\\($count\\)](green)'
renamed = "襁 "
deleted = " "

[terraform]
format = "via [ terraform $version]($style) 壟 [$workspace]($style) "

[vagrant]
format = "via [ vagrant $version]($style) "

[docker_context]
format = "via [ $context](bold blue) "

[helm]
format = "via [ $version](bold purple) "

[python]
symbol = " "
python_binary = "python3"

[nodejs]
format = "via [ $version](bold green) "
disabled = true

[ruby]
format = "via [ $version]($style) "

[kubernetes]
format = 'on [ $context\\($namespace\\)](bold purple) '
disabled = false

[kubernetes.context_aliases]
"clcreative-k8s-staging" = "cl-k8s-staging"
"clcreative-k8s-production" = "cl-k8s-prod"
'@
$starshipLinux | Set-Content -Path "$wslDir\starship-linux.toml" -Encoding UTF8 -Force

# ── neofetch TheDigitalLife ASCII ─────────────
$neofetchAscii = @'
      ██████ ███████████████████▇▅▖ 
      ██████   ████████████████████▙
      ██████     ███████████████████
          ████              ██████
██      ████                ██████
████  ████                  ██████
      ██████                   ██████
      ██████                   ██████
      ██████                   ██████
      ██████                   ██████
      ██████████ ███████████████████
      ████████   ██████████████████▛
      ██████     ████████████████▀▘ 
'@
$neofetchAscii | Set-Content -Path "$wslDir\.config\neofetch\thedigitallife.txt" -Encoding UTF8 -Force

Write-OK "WSL dotfiles written → $wslDir"
Write-Host ""
Write-Host "  Symlink into each WSL distro (run inside the distro):" -ForegroundColor DarkGray
Write-Host '  WIN_USER=$(cmd.exe /c echo %USERNAME% 2>/dev/null | tr -d "\r")' -ForegroundColor DarkGray
Write-Host '  DOTFILES="/mnt/c/Users/$WIN_USER/.wsl-dotfiles"' -ForegroundColor DarkGray
Write-Host '  ln -sf "$DOTFILES/.zshrc"  ~/.zshrc' -ForegroundColor DarkGray
Write-Host '  ln -sf "$DOTFILES/.bashrc" ~/.bashrc' -ForegroundColor DarkGray
Write-Host '  ln -sf "$DOTFILES/.zshenv" ~/.zshenv' -ForegroundColor DarkGray
Write-Host '  mkdir -p ~/.starship && ln -sf "$DOTFILES/starship-linux.toml" ~/.starship/starship.toml' -ForegroundColor DarkGray
Write-Host '  mkdir -p ~/.config/neofetch && ln -sf "$DOTFILES/.config/neofetch/thedigitallife.txt" ~/.config/neofetch/' -ForegroundColor DarkGray

# ─────────────────────────────────────────────
#  8. FILES APP THEME  (TheDigitalLife.xaml)
# ─────────────────────────────────────────────
Write-Step "Deploying Files app theme (TheDigitalLife.xaml)"

$xamlTheme = @'
<ResourceDictionary
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    xmlns:BelowWindows10version1809="http://schemas.microsoft.com/winfx/2006/xaml/presentation?IsApiContractNotPresent(Windows.Foundation.UniversalApiContract, 7)"
    xmlns:Windows10version1809="http://schemas.microsoft.com/winfx/2006/xaml/presentation?IsApiContractPresent(Windows.Foundation.UniversalApiContract, 7)">
    <ResourceDictionary.ThemeDictionaries>
        <ResourceDictionary x:Key="Default">
            <SolidColorBrush x:Key="RootBackgroundBrush" Color="#AA171717" />
            <Color x:Key="SolidBackgroundFillColorBase">#171717</Color>
            <Color x:Key="SolidBackgroundFillColorSecondary">#171717</Color>
            <Color x:Key="SolidBackgroundFillColorTertiary">#1D1D1D</Color>
            <Color x:Key="SolidBackgroundFillColorQuarternary">#1D1D1D</Color>
            <SolidColorBrush x:Key="SolidBackgroundFillColorBaseBrush" Color="{ThemeResource SolidBackgroundFillColorBase}" />
            <SolidColorBrush x:Key="SolidBackgroundFillColorSecondaryBrush" Color="{ThemeResource SolidBackgroundFillColorSecondary}" />
            <SolidColorBrush x:Key="SolidBackgroundFillColorTertiaryBrush" Color="{ThemeResource SolidBackgroundFillColorTertiary}" />
            <SolidColorBrush x:Key="SolidBackgroundFillColorQuarternaryBrush" Color="{ThemeResource SolidBackgroundFillColorQuarternary}" />
            <Color x:Key="SolidBackgroundAcrylic">#1D1D1D</Color>
            <Color x:Key="SystemAccentColor">#2E2E2E</Color>
            <Color x:Key="SystemAccentColorDark1">#727272</Color>
            <SolidColorBrush x:Key="StatusBarBackgroundBrush" Color="{ThemeResource SolidBackgroundFillColorBase}" />
            <SolidColorBrush x:Key="NavigationToolbarBackgroundBrush" Color="{ThemeResource SolidBackgroundFillColorSecondary}" />
            <x:Double x:Key="SidebarTintOpacity">0.9</x:Double>
            <x:Double x:Key="SidebarTintLuminosityOpacity">0.9</x:Double>
            <SolidColorBrush x:Key="HorizontalTabControlBackgroundBrush" Color="{ThemeResource SolidBackgroundFillColorSecondary}" />
            <SolidColorBrush x:Key="TabViewItemHeaderBackground" Color="{ThemeResource SolidBackgroundFillColorSecondary}" />
            <SolidColorBrush x:Key="TabViewItemHeaderBackgroundSelected" Color="{ThemeResource SolidBackgroundFillColorQuarternary}" />
            <SolidColorBrush x:Key="TabViewItemHeaderBackgroundPressed" Color="{ThemeResource SolidBackgroundFillColorQuarternary}" />
            <SolidColorBrush x:Key="TabViewItemHeaderBackgroundPointerOver" Color="{ThemeResource SolidBackgroundFillColorQuarternary}" />
            <SolidColorBrush x:Key="TabContainerFillColorPrimary" Color="{ThemeResource SolidBackgroundFillColorSecondary}" />
            <SolidColorBrush x:Key="TabContainerFillColorSecondary" Color="{ThemeResource SolidBackgroundFillColorSecondary}" />
        </ResourceDictionary>
    </ResourceDictionary.ThemeDictionaries>
</ResourceDictionary>
'@

$filesThemeDir = "$env:LOCALAPPDATA\Packages\49306atecsolution.FilesUWP_et10x9a9vyk8t\LocalState\themes"
try {
    Ensure-Dir $filesThemeDir
    $xamlTheme | Set-Content -Path "$filesThemeDir\TheDigitalLife.xaml" -Encoding UTF8 -Force
    Write-OK "Files theme → $filesThemeDir\TheDigitalLife.xaml"
} catch {
    $desktopCopy = "$HOME\Desktop\TheDigitalLife.xaml"
    $xamlTheme | Set-Content -Path $desktopCopy -Encoding UTF8 -Force
    Write-Warn "Files app not installed — theme saved to Desktop: $desktopCopy"
}

# ─────────────────────────────────────────────
#  9. RAINMETER  xcad skin
# ─────────────────────────────────────────────
Write-Step "Deploying Rainmeter xcad skin"

$rmResources = "$HOME\Documents\Rainmeter\Skins\xcad\@Resources"
Ensure-Dir "$rmResources\Fonts"
Ensure-Dir "$rmResources\Images"

$rmVars = @'
[Variables]
; GENERAL SETTINGS
; ---
mFont = Anonymice Nerd Font
measuresBaseWidth = 75

; COLORS
; ---
White       = 255,255,255,255
MainBar     = 45,45,45,255
Grey        = 255,255,255,150
Green       = 121,142,25
Black       = 0,0,0,255
Blue        = 50,50,200
Red         = 200,50,30
FullRed     = 191,30,45,255
Yellow      = 237,184,42,150
Purple      = 72,0,255,255
Shadow      = 255,255,255,20
DarkShadow  = 0,0,0,50
Cyan        = 21,255,255,255
BrightGrey  = 226,226,226,255
MediumGrey  = 102,102,102,255
DarkGrey    = 30,30,30,255
BrightGreen = 0,200,0,255
'@
$rmVars | Set-Content -Path "$rmResources\Variables.inc" -Encoding UTF8 -Force
Write-OK "Rainmeter xcad Variables.inc → $rmResources"

# ─────────────────────────────────────────────
#  10. WINDOWS 11 DARK MODE
# ─────────────────────────────────────────────
Write-Step "Enabling Windows 11 Dark Mode"

try {
    $personalizePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    Set-ItemProperty -Path $personalizePath -Name "AppsUseLightTheme"    -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $personalizePath -Name "SystemUsesLightTheme" -Value 0 -Type DWord -Force
    Write-OK "Dark Mode enabled (Apps + System)"
} catch { Write-Warn "Failed to set dark mode: $_" }

# ─────────────────────────────────────────────
#  11. MR. ROBOT WALLPAPER  (ChristianLempa/hackbox)
# ─────────────────────────────────────────────
Write-Step "Downloading & applying Mr. Robot wallpaper"

$wallpaperDir  = "$HOME\Pictures\Wallpapers"
$wallpaperPath = "$wallpaperDir\mr-robot-wallpaper.png"
Ensure-Dir $wallpaperDir

try {
    Invoke-WebRequest `
        -Uri "https://raw.githubusercontent.com/ChristianLempa/hackbox/main/src/assets/mr-robot-wallpaper.png" `
        -OutFile $wallpaperPath -UseBasicParsing
    Write-OK "Wallpaper downloaded → $wallpaperPath"
} catch { Write-Warn "Download failed: $_" }

if (Test-Path $wallpaperPath) {
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
        [Wallpaper]::SystemParametersInfo(0x0014, 0, $wallpaperPath, 3) | Out-Null
        $desktopReg = "HKCU:\Control Panel\Desktop"
        Set-ItemProperty -Path $desktopReg -Name "Wallpaper"     -Value $wallpaperPath -Force
        Set-ItemProperty -Path $desktopReg -Name "WallpaperStyle" -Value "10"          -Force
        Set-ItemProperty -Path $desktopReg -Name "TileWallpaper"  -Value "0"           -Force
        Write-OK "Wallpaper applied (Fill mode)"
    } catch { Write-Warn "Could not apply wallpaper: $_" }
}

# ─────────────────────────────────────────────
#  12. POWERSHELL MODULES
# ─────────────────────────────────────────────
Write-Step "Installing PowerShell modules"

foreach ($mod in @("posh-git","Terminal-Icons")) {
    if (!(Get-Module -ListAvailable -Name $mod)) {
        Write-Host "      Installing $mod ..." -NoNewline
        try {
            Install-Module -Name $mod -Scope CurrentUser -Force -SkipPublisherCheck
            Write-Host " done" -ForegroundColor Green
        } catch { Write-Host " FAILED: $_" -ForegroundColor Yellow }
    } else {
        Write-Host "      $mod already installed" -ForegroundColor DarkGray
    }
}

# ─────────────────────────────────────────────
#  13. GIT GLOBALS
# ─────────────────────────────────────────────
Write-Step "Configuring Git globals"

git config --global core.autocrlf      input
git config --global core.editor        "code --wait"
git config --global init.defaultBranch main
git config --global pull.rebase        false
Write-OK "Git globals set"

# ─────────────────────────────────────────────
#  14. EXPLORER TWEAKS
# ─────────────────────────────────────────────
Write-Step "Explorer: show file extensions + hidden files"

$explorerReg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
Set-ItemProperty -Path $explorerReg -Name "HideFileExt"    -Value 0 -Type DWord -Force
Set-ItemProperty -Path $explorerReg -Name "Hidden"          -Value 1 -Type DWord -Force
Set-ItemProperty -Path $explorerReg -Name "ShowSuperHidden" -Value 1 -Type DWord -Force
Write-OK "Explorer settings updated"

# ─────────────────────────────────────────────
#  15. RESTART EXPLORER
# ─────────────────────────────────────────────
Write-Step "Restarting Explorer"

try {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer
    Write-OK "Explorer restarted"
} catch { Write-Warn "Restart Explorer manually if needed." }

# ─────────────────────────────────────────────
#  DONE
# ─────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "  Setup complete!  Open a new Windows Terminal to see:                 " -ForegroundColor Green
Write-Host "                                                                       "
Write-Host "    Prompt:   ╭╴  xcad on <k8s-ctx> at ~ via v3.x.x                  " -ForegroundColor Cyan
Write-Host "              ╰─                                                       " -ForegroundColor Cyan
Write-Host "    Scheme:   xcad (dark #1A1A1A, blue-violet — your original colors)  " -ForegroundColor Cyan
Write-Host "    Font:     Hack Nerd Font 14pt                                      " -ForegroundColor Cyan
Write-Host "    Tabs:     PowerShell  Ubuntu  Kali  Arch  Cmd  (Azure hidden)      " -ForegroundColor Cyan
Write-Host "    Icons:    Nerd Font glyphs — no PNG files needed                   " -ForegroundColor Cyan
Write-Host "    eza:      ls / ll / la / lt with Nerd Font icons                   " -ForegroundColor Cyan
Write-Host "    WSL:      $HOME\.wsl-dotfiles\  (symlink into each distro)   " -ForegroundColor Cyan
Write-Host "    Wallpaper: $wallpaperPath                               " -ForegroundColor Cyan
Write-Host "                                                                       "
Write-Host "  NOTE: If WSL distros need a reboot to activate, reboot and re-run.  " -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""
