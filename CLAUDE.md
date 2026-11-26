# CLAUDE.md

Quick reference for Claude Code working with the Jellybuntu Wiki repository.

---

## About This Repository

This is the **documentation wiki** for the Jellybuntu infrastructure project. It contains
operator-facing documentation, built with MkDocs and served at
`https://docs.elysium.industries` (k3s Traefik → NAS nginx; direct fallback
`http://nas.discus-moth.ts.net:8082`).

**Related Repositories:**

| Repo | Local Path | Purpose |
|------|-----------|---------|
| [SilverDFlame/jellybuntu](https://forgejo.discus-moth.ts.net/SilverDFlame/jellybuntu) (Forgejo) | `~/coding/jellybuntu` | Ansible/Terraform IaC (`main`; k3s/Cilium migration done) |
| [SilverDFlame/jellybuntu-helm](https://github.com/SilverDFlame/jellybuntu-helm) (GitHub until Forgejo P3) | `~/coding/jellybuntu-helm` | Flux GitOps k3s manifests |
| [SilverDFlame/jellybuntu-wiki](https://forgejo.discus-moth.ts.net/SilverDFlame/jellybuntu-wiki) (Forgejo) | `~/coding/jellybuntu-wiki` | This wiki (MkDocs) |

---

## Documentation Structure

```text
docs/
├── index.md                 # Service dashboard, quick links, repo map
├── architecture.md          # Hybrid VM+k3s design, diagrams
├── infrastructure/          # VMs, networking, storage, GPU
├── services/                # One page per service (26 pages)
├── operations/              # Deployment, k3s cluster, k3s namespaces, helm repo, flux image automation, backups, secrets, updates
└── troubleshooting.md       # Common issues (single page)
```

---

## Cross-Repository References

**External code links** use absolute GitHub URLs:

> Forgejo migration: the existing `github.com/SilverDFlame/jellybuntu` links still resolve, because
> the frozen GitHub copy is a push-mirror target of Forgejo `main` until Forgejo P4. P4 rewrites
> every such link (and this convention) to the Forgejo form
> `https://forgejo.discus-moth.ts.net/SilverDFlame/jellybuntu/src/branch/main/{path}` in one pass.
> Until then keep new links in the GitHub form so the pages stay consistent.

```markdown
Good: [`roles/jellyfin/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/jellyfin)
Good: [`clusters/jellybuntu/media/`](https://github.com/SilverDFlame/jellybuntu-helm/tree/main/clusters/jellybuntu/media)
Bad:  `../playbooks/main.yml` (relative path - doesn't exist in wiki)
```

URL patterns:

- jellybuntu files: `https://github.com/SilverDFlame/jellybuntu/blob/main/{path}`
- jellybuntu dirs: `https://github.com/SilverDFlame/jellybuntu/tree/main/{path}`
- jellybuntu-helm files: `https://github.com/SilverDFlame/jellybuntu-helm/blob/main/{path}`

**Internal wiki links** stay relative:

```markdown
Good: [Architecture](architecture.md)
Good: [Sonarr](services/sonarr.md)
```

---

## Service Page Template

Every service page follows this structure:

```markdown
# Service Name

> One-line description

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace / VM `nas` (300) |
| **Access** | `https://sonarr.elysium.industries` |
| **Port** | 8989 |
| **Database** | PostgreSQL `sonarr_main`, `sonarr_log` on `db` VM |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/sonarr.yaml` |

## Key Config

(Non-obvious configuration notes)

## Common Operations

(Restart, logs, troubleshooting)
```

Include only applicable fields (e.g., no Database row for services without one).

---

## Development Workflow

### Local Preview

```bash
pip install -r requirements.txt
mkdocs serve
# View at http://localhost:8000
```

### Build and Validate

```bash
mkdocs build --strict
pre-commit run --all-files
```

---

## Markdown Style Guide

### Linting Rules (Pre-commit Enforced)

| Rule | Constraint |
|------|------------|
| **MD013** | Line length max 200 chars (code blocks/tables excluded) |
| **MD060** | Tables need leading + trailing pipes |
| **MD031** | Blank lines around fenced code blocks (markdownlint default) |
| **MD032** | Blank lines around lists (markdownlint default) |
| **MD040** | Code blocks need language tags (markdownlint default) |

**Language tags**: Use `bash` for commands, `yaml` for config, `text` for generic output.

### Relaxed Rules

| Rule | Setting |
|------|---------|
| **MD024** | siblings_only: true (duplicate headings OK if not siblings) |
| **MD033** | disabled (inline HTML allowed) |
| **MD034** | disabled (bare URLs allowed) |
| **MD041** | disabled (first line doesn't need to be h1) |

---

## CI/CD Pipeline

Documentation is automatically built and deployed via Woodpecker CI
(`https://automation.discus-moth.ts.net`), driven by **Forgejo** webhooks since 2026-11-26.
PRs opened on Forgejo run `build-docs` only; GitHub no longer triggers anything.

**Trigger:** Push to `main` branch (changes to `docs/`, `mkdocs.yml`, or `requirements.txt`)

**Pipeline:**

1. **build-docs**: `mkdocs build --strict`
2. **deploy-docs**: rsync to `nas.discus-moth.ts.net:/opt/docs/site/`

**Secret required:** `ssh_ci_private_key`

---

## Git Workflow

The repo lives on **Forgejo**: `origin` is
`ssh://git@forgejo.discus-moth.ts.net:2222/SilverDFlame/jellybuntu-wiki.git`
(web: `https://forgejo.discus-moth.ts.net/SilverDFlame/jellybuntu-wiki`). `main` is
protected there: direct push only for `SilverDFlame`, everything else through PRs, and only
Andrew merges (default merge style squash).

**GitHub (`SilverDFlame/jellybuntu-wiki`) is a frozen push-mirror target until Forgejo P4.**
Never push, merge or open PRs there: the Forgejo push mirror force-pushes `main` (silently
overwriting anything landed on GitHub) and deletes every non-`main` branch on GitHub.

```bash
git checkout -b docs/your-improvement
# Make changes
git commit -m "docs: Description of changes"
git push -u origin docs/your-improvement   # prints the Forgejo PR-create URL
# Agents open the PR as the agent user:
tea pulls create --login forgejo-agent --repo SilverDFlame/jellybuntu-wiki \
  --head docs/your-improvement --base main --title "docs: Description of changes"
```

Branch prefixes: `docs/`, `fix/`, `feature/`

---

## Quick Reference

| Task | Command/Location |
|------|------------------|
| Preview docs | `mkdocs serve` |
| Build docs | `mkdocs build --strict` |
| Run linting | `pre-commit run --all-files` |
| Main repo | [SilverDFlame/jellybuntu](https://forgejo.discus-moth.ts.net/SilverDFlame/jellybuntu) (Forgejo) |
| Helm repo | [SilverDFlame/jellybuntu-helm](https://github.com/SilverDFlame/jellybuntu-helm) (GitHub until Forgejo P3) |
| Hosted docs | https://docs.elysium.industries (fallback http://nas.discus-moth.ts.net:8082) |
