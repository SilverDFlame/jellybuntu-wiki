# CLAUDE.md

Quick reference for Claude Code working with the Jellybuntu Wiki repository.

---

## 📚 About This Repository

This is the **documentation wiki** for the Jellybuntu infrastructure project. It contains all user-facing
documentation, built with MkDocs and deployed to `http://nas.discus-moth.ts.net:8082`.

**Main Infrastructure Repository:** [SilverDFlame/jellybuntu](https://github.com/SilverDFlame/jellybuntu)

---

## 🔗 Cross-Repository References

This wiki references code from the main Jellybuntu repository. **Always use absolute GitHub URLs** for code paths:

```markdown
✅ Good: [`playbooks/main.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/main.yml)
✅ Good: [`roles/jellyfin/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/jellyfin)
❌ Bad: `../playbooks/main.yml` (relative path - doesn't exist in wiki)
❌ Bad: `playbooks/main.yml` (no link - not navigable)
```

**URL patterns:**

- Files: `https://github.com/SilverDFlame/jellybuntu/blob/main/{path}`
- Directories: `https://github.com/SilverDFlame/jellybuntu/tree/main/{path}`

**Internal wiki links** stay relative:

```markdown
✅ Good: [Architecture](architecture.md)
✅ Good: [Service Endpoints](configuration/service-endpoints.md)
```

---

## 📂 Documentation Structure

```text
docs/
├── index.md                 # Documentation home
├── quickstart.md            # Getting started guide
├── architecture.md          # Infrastructure overview
├── CLAUDE.md                # Documentation authoring guide
├── deployment/              # Deployment guides (phases, initial setup)
├── configuration/           # Service configuration guides
├── maintenance/             # Operational procedures
├── reference/               # Technical reference docs
├── troubleshooting/         # Service-specific troubleshooting
├── development/             # Developer workflows
└── archive/                 # Deprecated documentation
```

**See**: [docs/CLAUDE.md](docs/CLAUDE.md) for documentation authoring guidelines.

---

## 🛠️ Development Workflow

### Local Preview

```bash
# Install dependencies
pip install -r requirements.txt

# Start development server
mkdocs serve

# View at http://localhost:8000
```

### Build and Validate

```bash
# Build with strict mode (catches broken links)
mkdocs build --strict

# Run pre-commit checks
pre-commit run --all-files
```

### Pre-commit Hooks

This repo uses simplified pre-commit hooks for documentation:

| Hook | Purpose |
|------|---------|
| trailing-whitespace | Remove trailing whitespace |
| end-of-file-fixer | Ensure newline at EOF |
| check-yaml | Validate YAML syntax |
| mixed-line-ending | Enforce LF line endings |
| yamllint | Lint mkdocs.yml |
| markdownlint-cli2 | Lint markdown files |

---

## 🏷️ Markdown Style Guide

### Key Rules (Pre-commit Enforced)

| Rule | Constraint |
|------|------------|
| **MD013** | Line length max 120 chars (code blocks/tables excluded) |
| **MD031** | Blank lines around fenced code blocks |
| **MD032** | Blank lines around lists |
| **MD040** | Code blocks need language tags |

### Common Fixes

```markdown
<!-- BAD: No language tag -->
` ` `
some output
` ` `

<!-- GOOD: Language specified -->
` ` `text
some output
` ` `

<!-- BAD: No blank line before list -->
**Steps**:
1. First step

<!-- GOOD: Blank line before list -->
**Steps**:

1. First step
```

**Language tags**: Use `bash` for commands, `yaml` for config, `text` for generic output.

---

## 🚀 CI/CD Pipeline

Documentation is automatically built and deployed via Woodpecker CI.

**Trigger:** Push to `main` branch (changes to `docs/`, `mkdocs.yml`, or `requirements.txt`)

**Pipeline:**

1. **build-docs**: Install deps, run `mkdocs build --strict`
2. **deploy-docs**: rsync to `nas.discus-moth.ts.net:/opt/docs/site/`

**Secret required:** `ssh_ci_private_key` (shared with main repo)

**Hosted at:** http://nas.discus-moth.ts.net:8082

---

## 📝 Git Workflow

**Use feature branches** for documentation changes:

```bash
git checkout -b docs/your-improvement
# Make changes
git add .
git commit -m "docs: Description of changes"
git push -u origin docs/your-improvement
# Create PR
```

**Branch naming:**

- `docs/` - Documentation improvements
- `fix/` - Fix broken links, typos
- `feature/` - New documentation sections

---

## 🔍 Quick Reference

| Task | Command/Location |
|------|------------------|
| Preview docs | `mkdocs serve` |
| Build docs | `mkdocs build --strict` |
| Run linting | `pre-commit run --all-files` |
| Authoring guide | [docs/CLAUDE.md](docs/CLAUDE.md) |
| Main repo | [SilverDFlame/jellybuntu](https://github.com/SilverDFlame/jellybuntu) |
| Hosted docs | http://nas.discus-moth.ts.net:8082 |

---

**For documentation authoring guidelines, see [docs/CLAUDE.md](docs/CLAUDE.md)**
