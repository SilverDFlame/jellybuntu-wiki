# Project Claude Code Settings

This directory contains shared Claude Code configuration for all developers working on this repository.

## Why is this in Git?

The `.claude/settings.json` file is committed to version control to ensure:

- **Consistent tooling** — all team members share the same marketplace registrations
- **Onboarding simplicity** — new developers get the correct setup automatically
- **Reproducible behavior** — Claude Code behaves the same way for everyone

## Files

- `settings.json` — shared project settings (marketplace registrations only)
- `README.md` — this file

## Scope vs. Sibling Repos

This is a docs-only repo (MkDocs). `settings.json` here registers only the
Claude Code marketplaces — it enables no plugins and defines no hooks:

- **Marketplaces**: registered so any plugin from them is installable, but which
  plugins are actually enabled is left to each developer's user settings.
- **No hooks**: the secret-leak guards previously kept in-repo have been
  consolidated into the shared dotfiles configuration, so no hook scripts ship
  in this repo.

## Personal Settings

Personal or machine-specific settings belong in your user directory:

```text
~/.claude/settings.json
```

User settings are merged with project settings, with user settings taking precedence.
Per-checkout overrides go in `.claude/settings.local.json` (gitignored).
