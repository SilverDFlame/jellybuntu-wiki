# Project Claude Code Settings

This directory contains shared Claude Code configuration for all developers working on this repository.

## Why is this in Git?

The `.claude/settings.json` file is committed to version control to ensure:

- **Consistent tooling** — all team members use the same plugins and marketplaces
- **Onboarding simplicity** — new developers get the correct setup automatically
- **Reproducible behavior** — Claude Code behaves the same way for everyone

## Files

- `settings.json` — shared project settings (marketplaces, enabled plugins, hooks)
- `hooks/` — pre-tool-use shell hooks (secret-leak guards)
- `README.md` — this file

## Scope vs. Sibling Repos

This is a docs-only repo (MkDocs). The plugin and hook set is a strict subset
of what `jellybuntu` and `jellybuntu-helm` ship:

- **Dropped plugins**: `ansible-dev` (no Ansible here), `semgrep` (no application
  code to scan, only Markdown).
- **Dropped hooks**: `block-secret-commands.sh` — its rules target SOPS,
  ansible-vault, and kubectl secret dumps, none of which run against this repo.
  Adding it would be a no-op cargo-cult.
- **Kept hook**: `block-secret-files.sh`, narrowed to `.credentials.json` and
  age private keys (defense in depth for Claude Code's own credential file).

## Hook Portability

`hooks/*.sh` are portable across macOS and Linux (Arch/Ubuntu):

- `#!/usr/bin/env bash` — locates bash via PATH, no hard-coded `/bin/bash`
- POSIX-only flags on `grep`, `basename` — works with both BSD (macOS) and
  GNU (Linux) coreutils
- No bash 4+ features — runs on macOS's stock bash 3.2 and bash 5.x alike
- External deps: `jq` only. Install with `brew install jq` (macOS) or
  `pacman -S jq` (Arch).

## Personal Settings

Personal or machine-specific settings belong in your user directory:

```text
~/.claude/settings.json
```

User settings are merged with project settings, with user settings taking precedence.
Per-checkout overrides go in `.claude/settings.local.json` (gitignored).
