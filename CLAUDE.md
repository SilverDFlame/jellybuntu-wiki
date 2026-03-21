# CLAUDE.md

Quick reference for Claude Code working with the Jellybuntu Wiki repository.

---

## About This Repository

This is the **documentation wiki** for the Jellybuntu infrastructure project. It contains
operator-facing documentation, built with MkDocs and deployed to
`http://nas.discus-moth.ts.net:8082`.

**Related Repositories:**

| Repo | Local Path | Purpose |
|------|-----------|---------|
| [SilverDFlame/jellybuntu](https://github.com/SilverDFlame/jellybuntu) | `~/coding/jellybuntu` | Ansible/Terraform IaC (use `feature/k3s-service-migration` branch) |
| [SilverDFlame/jellybuntu-helm](https://github.com/SilverDFlame/jellybuntu-helm) | `~/coding/jellybuntu-helm` | Flux GitOps k3s manifests |
| [SilverDFlame/jellybuntu-wiki](https://github.com/SilverDFlame/jellybuntu-wiki) | `~/coding/jellybuntu-wiki` | This wiki (MkDocs) |

---

## Documentation Structure

```text
docs/
├── index.md                 # Service dashboard, quick links, repo map
├── architecture.md          # Hybrid VM+k3s design, diagrams
├── infrastructure/          # VMs, networking, storage, GPU
├── services/                # One page per service (~21 pages)
├── operations/              # Deployment, k3s cluster, backups, secrets, updates
└── troubleshooting.md       # Common issues (single page)
```

---

## Cross-Repository References

**External code links** use absolute GitHub URLs:

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
| **MD013** | Line length max 120 chars (code blocks/tables excluded) |
| **MD031** | Blank lines around fenced code blocks |
| **MD032** | Blank lines around lists |
| **MD040** | Code blocks need language tags |

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

Documentation is automatically built and deployed via Woodpecker CI.

**Trigger:** Push to `main` branch (changes to `docs/`, `mkdocs.yml`, or `requirements.txt`)

**Pipeline:**

1. **build-docs**: `mkdocs build --strict`
2. **deploy-docs**: rsync to `nas.discus-moth.ts.net:/opt/docs/site/`

**Secret required:** `ssh_ci_private_key`

---

## Git Workflow

```bash
git checkout -b docs/your-improvement
# Make changes
git commit -m "docs: Description of changes"
git push -u origin docs/your-improvement
```

Branch prefixes: `docs/`, `fix/`, `feature/`

---

## Quick Reference

| Task | Command/Location |
|------|------------------|
| Preview docs | `mkdocs serve` |
| Build docs | `mkdocs build --strict` |
| Run linting | `pre-commit run --all-files` |
| Main repo | [SilverDFlame/jellybuntu](https://github.com/SilverDFlame/jellybuntu) |
| Helm repo | [SilverDFlame/jellybuntu-helm](https://github.com/SilverDFlame/jellybuntu-helm) |
| Hosted docs | http://nas.discus-moth.ts.net:8082 |
