# Cross-Repo Documentation Sync Trigger

**Date:** 2026-03-03
**Status:** Design approved, pending implementation

---

## Problem

Documentation in the jellybuntu-wiki repo drifts out of sync with the main
jellybuntu infrastructure repo. Currently, documentation sync is entirely
manual — someone notices changes, spawns a Claude Code agent team, and
coordinates updates. There's no automated notification when infrastructure
changes affect documentation.

## Solution

A **GitHub Actions `repository_dispatch` pipeline** that:

1. Detects doc-relevant pushes to the main jellybuntu repo
2. Fires a cross-repo event to the wiki repo with the changed file list
3. Matches changed files against a YAML mapping of infra paths → doc pages
4. Opens a GitHub Issue with a checklist of affected documentation pages

## Architecture

```text
jellybuntu (main repo)              jellybuntu-wiki (this repo)
┌─────────────────────┐             ┌──────────────────────────┐
│ push to main        │             │                          │
│ (roles/**, etc.)    │             │  .github/                │
│                     │             │  ├── sync-mapping.yml    │
│ .github/workflows/  │  dispatch   │  └── workflows/          │
│ notify-wiki.yml     │────────────▶│      doc-sync-check.yml  │
│                     │  payload:   │                          │
│ Sends:              │  files,     │  Receives dispatch,      │
│ - changed files     │  commit,    │  reads mapping,          │
│ - commit context    │  author     │  opens GitHub Issue      │
└─────────────────────┘             └──────────────────────────┘
```

## Components

### 1. Mapping File (wiki repo)

**Location:** `.github/sync-mapping.yml`

Maps infra repo glob patterns to wiki documentation pages.

```yaml
mappings:
  - infra_globs: ["roles/jellyfin/**", "roles/jellyfin_config/**"]
    wiki_pages: ["configuration/jellyfin.md", "troubleshooting/jellyfin.md"]
    context: "Jellyfin service or media configuration"

  - infra_globs: ["roles/traefik_proxy/**"]
    wiki_pages: ["configuration/traefik-setup.md", "configuration/service-endpoints.md"]
    context: "Reverse proxy routing or TLS configuration"

  # ... more entries ...

  - infra_globs: ["roles/**"]
    wiki_pages: []
    context: "Ansible role (no specific doc page mapped yet)"
```

**Design decisions:**

- YAML format — consistent with project conventions
- `infra_globs` use GitHub Actions glob syntax (via `minimatch`)
- `wiki_pages: []` for catch-all entries — still surfaces in issues as "unmapped"
- `context` provides human-readable description for issue body
- First matching entry wins (specific before catch-all)

### 2. Sender Workflow (main repo)

**Location:** `jellybuntu/.github/workflows/notify-wiki.yml`

**Triggers:** Push to `main` when these paths change:

- `roles/**`
- `playbooks/**`
- `infrastructure/**`
- `group_vars/**`
- `host_vars/**`
- `services/**`

**Actions:**

1. Collects changed files via `tj-actions/changed-files` (JSON output)
2. Fires `repository_dispatch` to `SilverDFlame/jellybuntu-wiki`
3. Event type: `infra-changed`
4. Payload: changed files, commit SHA, message, URL, author

**Secret required:** `WIKI_DISPATCH_TOKEN` — a GitHub PAT with `repo` scope
on the wiki repository.

### 3. Receiver Workflow (wiki repo)

**Location:** `.github/workflows/doc-sync-check.yml`

**Triggers:** `repository_dispatch` with type `infra-changed`

**Actions:**

1. Checks out wiki repo (to read mapping file)
2. Parses `.github/sync-mapping.yml`
3. Matches each changed file against mapping globs (first match wins)
4. Deduplicates wiki pages (multiple infra files → same page)
5. Opens a GitHub Issue with:
   - Commit link and author
   - Checklist of affected doc pages (with links)
   - List of unmapped changes
   - `doc-sync` label

**Issue format:**

```markdown
## Infrastructure Changes Detected

**Commit:** [`abc1234`](https://github.com/.../commit/abc1234)
**Author:** username
**Message:** feat: add matrix federation support

### Doc Pages to Review

- [ ] [`configuration/matrix-setup.md`](link)
  - `roles/matrix/**` — Matrix/Synapse service configuration
- [ ] [`configuration/service-endpoints.md`](link)
  - `roles/traefik_proxy/**` — Reverse proxy routing

### Unmapped Changes (may need new doc pages)

- `roles/new_role/**` — Ansible role (no specific doc page mapped yet)
```

## Secrets & Permissions

| Secret | Repo | Purpose |
|--------|------|---------|
| `WIKI_DISPATCH_TOKEN` | jellybuntu (main) | PAT to dispatch events to wiki repo |

The PAT needs `repo` scope on `SilverDFlame/jellybuntu-wiki`. This can be the
same token used for other cross-repo operations, or a dedicated fine-grained
PAT scoped to just the wiki repo.

## Full Mapping Coverage

Based on current infra repo structure and wiki nav:

| Infra Paths | Wiki Pages | Context |
|-------------|------------|---------|
| `roles/jellyfin/**`, `roles/jellyfin_config/**` | `configuration/jellyfin.md`, `troubleshooting/jellyfin.md` | Jellyfin service |
| `roles/traefik_proxy/**` | `configuration/traefik-setup.md`, `configuration/service-endpoints.md` | Reverse proxy |
| `roles/ufw_firewall/**` | `configuration/security.md`, `configuration/networking.md` | Firewall rules |
| `roles/tailscale/**` | `configuration/networking.md`, `reference/tailscale-auto-approval.md` | Tailscale VPN |
| `roles/unifi_controller/**` | `configuration/unifi-controller-setup.md` | UniFi controller |
| `roles/monitoring_stack/**`, `roles/node_exporter/**` | `configuration/monitoring.md` | Monitoring |
| `roles/podman_app/**` | `reference/container-versioning.md` | Container management |
| `roles/common/**`, `roles/unattended_upgrades/**` | `maintenance/updates.md` | System updates |
| `roles/btrfs_*/**` | `maintenance/backup-recovery.md` | Storage/backups |
| `roles/nfs_*/**` | `configuration/networking.md` | NFS shares |
| `roles/ssh_authorized_keys/**` | `reference/ssh-bastion.md`, `configuration/security.md` | SSH access |
| `roles/unbound/**` | `configuration/networking.md` | DNS resolver |
| `roles/proxmox_host/**` | `reference/proxmox-api-permissions.md`, `architecture.md` | Proxmox host |
| `roles/lancache/**` | `configuration/lancache.md` | LAN cache |
| `roles/satisfactory/**` | *(no wiki page yet)* | Game server |
| `playbooks/phases/**` | `deployment/phase-based-deployment.md` | Deployment phases |
| `playbooks/services/**` | `configuration/service-endpoints.md` | Service playbooks |
| `playbooks/networking/**` | `configuration/networking.md`, `reference/vlan-migration.md` | Network playbooks |
| `playbooks/system/**` | `maintenance/updates.md` | System playbooks |
| `playbooks/monitoring/**` | `configuration/monitoring.md` | Monitoring playbooks |
| `playbooks/main.yml` | `reference/playbooks.md` | Main playbook |
| `infrastructure/terraform/**` | `reference/terraform-modules.md`, `architecture.md` | Terraform |
| `infrastructure/packer/**` | `deployment/golden-image-workflow.md`, `troubleshooting/packer.md` | Packer images |
| `infrastructure/containers/**` | `reference/container-versioning.md` | Container definitions |
| `group_vars/**`, `host_vars/**` | `architecture.md` | Ansible variables |
| `services/**` | `configuration/service-endpoints.md` | Service definitions |
| `roles/**` | *(catch-all)* | Unmapped role changes |

## Setup Instructions (Manual)

### 1. Create a GitHub PAT

1. Go to <https://github.com/settings/tokens?type=beta> (fine-grained tokens)
2. Token name: `wiki-dispatch`
3. Expiration: 90 days (set a calendar reminder to rotate)
4. Repository access: "Only select repositories" → `SilverDFlame/jellybuntu-wiki`
5. Permissions:
   - Contents: Read
   - Issues: Read and write
   - Metadata: Read (auto-selected)
6. Generate token and copy it

### 2. Add secret to main repo

1. Go to <https://github.com/SilverDFlame/jellybuntu/settings/secrets/actions>
2. Click "New repository secret"
3. Name: `WIKI_DISPATCH_TOKEN`
4. Value: paste the PAT from step 1
5. Click "Add secret"

### 3. Test the pipeline

After both workflows are merged to their respective `main` branches:

1. Make a trivial change to any mapped file in the main repo (e.g.,
   add a comment to `roles/common/tasks/main.yml`)
2. Push to main
3. Check GitHub Actions in the main repo — `notify-wiki.yml` should run
4. Check GitHub Actions in the wiki repo — `doc-sync-check.yml` should trigger
5. Check Issues in the wiki repo — a new `doc-sync` issue should appear

## Future Enhancements

- **Deduplication:** Check for open `doc-sync` issues before creating new ones
  to avoid flooding when the infra repo has rapid commits
- **@claude integration:** Add a comment template that triggers the existing
  Claude Code Action to draft documentation updates
- **Priority labels:** Map certain infra paths to `high-priority` label
  (e.g., security-related changes)
- **Stale detection:** Scheduled workflow to check if any `doc-sync` issues
  have been open > 7 days and add a reminder comment
