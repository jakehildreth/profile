# profile

Cross-platform shell profiles for PowerShell, bash, zsh, and fish with consistent keybindings, a git-aware prompt, and self-updating installs.

## Profiles

| File | Shell |
|---|---|
| `profiles/DollarSignPROFILE.ps1` | PowerShell (pwsh + Windows PowerShell) |
| `profiles/dotbashrc` | bash |
| `profiles/dotzshrc` | zsh |
| `profiles/configdotfish` | fish |

## Quick Start

### PowerShell

```powershell
iwr profile.jakehildreth.com | iex
```

### bash / zsh / fish

```bash
curl profile.jakehildreth.com | $SHELL
```

The installer detects your shell automatically, backs up your existing `$PROFILE`/`.zshrc`/`.bashrc`/`~/.config/fish/config.fish` file with a timestamp, writes the new profile, and reloads your shell.

On each subsequent interactive terminal session, the profile loads and checks for updates.

## Features

### Keybindings

Consistent across all four shells on Windows and macOS:

| Chord | Action |
|---|---|
| `Ctrl+U` | Clear to start of line |
| `Escape` | Revert/clear line |
| `Alt+Left` / `Ctrl+Left` | Backward word |
| `Alt+Right` / `Ctrl+Right` | Forward word |
| `Alt+Backspace` / `Ctrl+Backspace` | Delete word backward |
| `Ctrl+Delete` / `Alt+Delete` | Delete word forward |

### Prompt

Displays terminal dimensions, current path, git branch, and shell name.

```
[100x35] ~/dev/profile [main]
fish>
```

### Functions

- `New-Credential` / `new_credential` — interactive credential prompt, cross-platform
- `Get-IPAddress` / `get_ip_address` — lists non-loopback IPv4 addresses
- `gai` — copies AI instruction URLs to clipboard for use with GitHub Copilot
- `New-Function` — scaffolds a new PowerShell function file with comment-based help

### Auto-Update

On each interactive session, the profile fetches the latest version. Behavior is controlled by an optional header line in your rc file:

```
# AutoUpdate=never   # skip all updates silently
# AutoUpdate=always  # always update without prompting
```

When an update is available and no preference is set, you are prompted with a diff view and four options: update always, update once, skip once, or skip forever.

## Installers

| File | Description |
|---|---|
| `installers/install.sh` | bash/zsh/fish installer (curl-pipeable) |
| `installers/Install-DollarSignPROFILE.ps1` | PowerShell installer (iwr-pipeable) |

Both installers:
- create a timestamped backup before any write
- respect existing `AutoUpdate` preferences
- show a color-coded diff on request
- reload the shell after a successful install

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

Made with 💜 by [Jake Hildreth](https://jakehildreth.com)
