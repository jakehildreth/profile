# ADR-0007: Fish Shell Support for DollarSignPROFILE

**Date:** 2026-07-12
**Status:** Accepted

---

## Context

`DollarSignPROFILE` supports PowerShell, bash, and zsh. Fish is a popular interactive
shell with a distinct syntax and configuration model. Users who run fish have no
DollarSignPROFILE equivalent. This ADR records the decisions made when adding fish
support.

---

## Decisions

### 1. Separate `configdotfish` file over a shared shell rc

**Decision:** Produce `profiles/configdotfish` as an independent file, parallel to
`dotbashrc` and `dotzshrc`.

**Rationale:** Fish syntax differs fundamentally from POSIX shell syntax. Functions
use `function ... end`, variables use `set`, conditionals use `test` or `string`,
and prompts use `fish_prompt`. A shared file full of shell-detection guards would
be unreadable and error-prone. A dedicated file lets the fish profile use idiomatic
fish constructs and be reviewed in isolation.

**Rejected:** A single `dotshrc` with `if fish` guards; reusing `dotbashrc` syntax
inside a fish config.

---

### 2. Install to `~/.config/fish/config.fish`

**Decision:** The fish installer writes to the standard fish config path
`$HOME/.config/fish/config.fish`.

**Rationale:** This is the conventional, XDG-compliant location fish reads on startup.
Using the standard path means the profile loads automatically without requiring the
user to source it manually.

**Rejected:** Installing to a custom path and appending a source line; using a
universal variable to point at an alternative file.

---

### 3. Feature parity with bash/zsh profiles

**Decision:** `configdotfish` implements the same set of features as `dotbashrc` and
`dotzshrc`: self-update, UTF-8 locale, keybindings, `calver`, `new_credential`,
git-aware prompt, `get_ip_address`, `gai`, and `dcc`.

**Rationale:** The goal of DollarSignPROFILE is a consistent experience across shells.
A fish user should have the same productivity utilities and prompt information as a
bash or zsh user.

**Rejected:** A reduced feature set for fish; shell-specific features beyond what
the other profiles provide.

---

### 4. Do not add fish plugins or extras

**Decision:** The profile does not install, source, or configure any fish plugins
(e.g., oh-my-fish, fisher, tide). It also does not enable built-in features fish
already has, such as syntax highlighting or autosuggestions.

**Rationale:** Fish already provides syntax highlighting and autosuggestions by
default. Adding plugin management would introduce dependencies and maintenance burden
that the bash and zsh profiles do not have. The scope is parity with existing profiles,
not enhancing fish beyond them.

**Rejected:** Adding `fisher` plugin installation; sourcing third-party theme packages;
conditionally installing plugins.

---

### 5. Use fish-native constructs for equivalent behavior

**Decision:** When a POSIX shell idiom has no direct fish equivalent, use the
fish-native approach rather than forcing POSIX compatibility.

**Examples:**
- Flags for `gai` are parsed with `argparse` instead of `getopts`.
- The prompt is implemented as `fish_prompt` instead of a precmd hook.
- The current directory display uses `string replace` to substitute `~` for `$HOME`.
- Interactive-only setup is guarded with `status --is-interactive`.

**Rationale:** Fish users expect fish syntax. Translating POSIX patterns literally
results in awkward or broken code (e.g., fish has no `$BASH_SOURCE`, no `PROMPT_COMMAND`,
and different word-splitting rules). Native constructs are more reliable and readable.

**Rejected:** Wrapping fish in `bash -c` blocks to reuse bash logic; emulating POSIX
word-splitting with `eval`.

---

### 6. Self-update runs the shared `install.sh` via `psub`

**Decision:** `configdotfish` self-update runs `bash (curl ... | psub)`, passing the
install script to bash through a temporary file.

**Rationale:** The install script is written in bash and detects the parent shell
from `$PPID`. When launched from fish, `$PPID` resolves to `fish`, so the installer
selects the fish profile and config path. `psub` is the standard fish idiom for
piping content into a command that expects a file path.

**Rejected:** Rewriting `install.sh` in fish; writing a separate fish-only installer;
using `bash -c` with a here-string (which would make `$PPID` report bash instead of
fish).

---

### 7. Keep `New-Function` PowerShell-only

**Decision:** `New-Function` is not ported to fish.

**Rationale:** `New-Function` scaffolds PowerShell function files with
`CmdletBinding`, approved verbs, and comment-based help. It has no meaningful
equivalent in fish and would require a full redesign to produce fish function
templates. This mirrors the existing decision in ADR-0002 to exclude `New-Function`
from bash and zsh.

**Rejected:** Porting `New-Function` to scaffold fish function files.
