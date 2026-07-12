# ADR-0006: CalVer Version Header in Profile Files

**Date:** 2026-04-18
**Status:** Accepted

---

## Context

The managed profile files (`DollarSignPROFILE.ps1`, `dotbashrc`, `dotzshrc`, `dotfishrc`) had
no version information in their headers. When a user reports a bug or asks for help,
there is no way to confirm which version of the profile is installed without diffing
against the repo. The project already uses CalVer (`yyyy.M.dHHmm`) for all other
versioning decisions.

---

## Decisions

### 1. Add `# Version` header to all profile files

**Decision:** Each profile file includes a `# Version yyyy.M.dHHmm` line as the second
line of the file, between the filename comment and the source URL comment:

```
# <filename>
# Version 2026.4.180945
# https://github.com/jakehildreth/profile/profiles/<filename>
```

**Rationale:** Visible in the file without executing it. Consistent across all
profiles. CalVer encodes the exact date and time of the last change, making it
unambiguous which "version" of the profile is installed.

---

### 2. Version must be updated on every profile change

**Decision:** Any modification to `DollarSignPROFILE.ps1`, `dotbashrc`, `dotzshrc`, or `dotfishrc`
must include a version bump to the `# Version` header reflecting the actual date and
time of the change. This rule is encoded in `.github/copilot-instructions.md`.

**Rationale:** A stale version header is worse than no header — it implies the file
hasn't changed when it has. Encoding the rule in Copilot instructions ensures it is
enforced automatically during AI-assisted edits.

---

### 3. Source URL in header points directly to the file, not the repo root

**Decision:** The URL comment points to the specific file path:
`https://github.com/jakehildreth/profile/profiles/<filename>`

**Rationale:** The previous header used the repo root URL, which required navigating to
find the file. A direct file URL is immediately actionable for comparison or raw download.
