# Jellybuntu Wiki Rewrite Design

**Date:** 2026-03-20
**Status:** Approved

---

## Context

The jellybuntu infrastructure has undergone a major migration from Docker Compose + VM-based
services to a hybrid Proxmox VM + k3s Kubernetes architecture (feature/k3s-service-migration
branch, 37 commits, 93 files changed). The existing wiki (~90 markdown files, ~61K lines)
documents the old architecture and is now almost entirely wrong. The cross-repo doc-sync CI
action never worked. A fresh start is warranted.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Audience | Personal reference (operator only) | Solo homelab, no onboarding needed |
| State documented | Final state only | k3s migration treated as complete, no artifacts |
| Cross-repo model | Wiki is the glue; repos self-document | jellybuntu and jellybuntu-helm have their own READMEs/CLAUDE.md |
| Service granularity | One page per service | Short, focused, consistent template |
| CI/CD | Woodpecker deploy + Claude PR review | Drop broken doc-sync-check Action |
| Archive | Delete entirely | Git history preserves everything |

## Scope

### Delete

- All files under `docs/` (90+ markdown files including archive/, plans/, all subdirectories)
- `docs/CLAUDE.md` (authoring guide — conventions folded into root `CLAUDE.md`)
- `.github/workflows/doc-sync-check.yml`
- `.github/sync-mapping.yml` (if present)

### Keep (unchanged)

- MkDocs Material theme config (plugins, extensions, features)
- `requirements.txt` (mkdocs~=1.6.0, mkdocs-material~=9.5.0, mkdocs-mermaid2-plugin~=1.1.1, pymdown-extensions~=10.7)
- `.woodpecker.yml` (build + rsync deploy to nas.discus-moth.ts.net:8082)
- `.github/workflows/claude.yml` (PR review)
- `.pre-commit-config.yaml` + `.markdownlint-cli2.yaml`

### Rewrite

- `mkdocs.yml` nav section and `site_description` (new structure; theme/plugins/extensions stay;
  remove stale `exclude_docs: archive/` and update `validation` comment)
- Root `CLAUDE.md` (updated directory structure, absorb authoring conventions from deleted `docs/CLAUDE.md`)

## New Documentation Structure

```text
docs/
├── index.md                    # Service dashboard, quick links, repo map
├── architecture.md             # Hybrid VM+k3s design, diagrams
├── infrastructure/
│   ├── vms.md                  # VM inventory: VMID, IP, VLAN, resources, boot order
│   ├── networking.md           # VLANs, DNS chain, dual Traefik ingress, MetalLB, Tailscale
│   ├── storage.md              # Btrfs RAID1, NFS exports, NVMe PVCs, mount paths
│   └── gpu.md                  # Proxmox passthrough, NVIDIA device plugin, time-slicing
├── services/
│   ├── jellyfin.md             # k3s gpu namespace, GPU transcoding
│   ├── tdarr.md                # k3s gpu namespace, transcode workflows
│   ├── sonarr.md               # k3s media namespace, PostgreSQL backend
│   ├── radarr.md               # k3s media namespace, PostgreSQL backend
│   ├── prowlarr.md             # k3s media namespace, indexer management
│   ├── bazarr.md               # k3s media namespace, subtitles
│   ├── lidarr.md               # k3s media namespace, music
│   ├── jellyseerr.md           # k3s media namespace, request management
│   ├── navidrome.md            # k3s media namespace, music streaming
│   ├── qbittorrent.md          # k3s media namespace, torrent client
│   ├── sabnzbd.md              # k3s media namespace, usenet client
│   ├── unpackerr.md            # k3s media namespace, archive extraction
│   ├── matrix.md               # k3s ops namespace, Synapse + synapse-admin + lk-jwt
│   ├── postgresql.md           # Dedicated VM (db/415), databases, k8s access
│   ├── adguard.md              # NAS VM, DNS rewrites, blocklists, Unbound upstream
│   ├── monitoring.md           # k3s ops (Prometheus/Grafana) + VM exporters
│   ├── home-assistant.md       # Dedicated VM, Podman, Tailscale-only access
│   ├── satisfactory.md         # Dedicated VM, CPU-pinned game server
│   ├── lancache.md             # Dedicated VM, game download cache
│   ├── nexus.md                # NAS VM, container registry mirror for k3s
│   └── woodpecker.md           # k3s ops namespace, CI/CD
├── operations/
│   ├── deployment.md           # Phase-based deployment (phases 1-5), playbook reference
│   ├── k3s-cluster.md          # Flux GitOps workflow, kubectl, node ops, adding services
│   ├── backups.md              # Btrfs snapshots, recovery procedures
│   ├── secrets.md              # SOPS/age encryption, rotation
│   └── updates.md              # OS patches, service updates, Flux reconciliation
└── troubleshooting.md          # Single page, common issues by category
```

**Total: ~34 pages**

## MkDocs Navigation

```yaml
nav:
  - Home: index.md
  - Architecture: architecture.md
  - Infrastructure:
    - Virtual Machines: infrastructure/vms.md
    - Networking: infrastructure/networking.md
    - Storage: infrastructure/storage.md
    - GPU: infrastructure/gpu.md
  - Services:
    - Jellyfin: services/jellyfin.md
    - Tdarr: services/tdarr.md
    - Sonarr: services/sonarr.md
    - Radarr: services/radarr.md
    - Prowlarr: services/prowlarr.md
    - Bazarr: services/bazarr.md
    - Lidarr: services/lidarr.md
    - Jellyseerr: services/jellyseerr.md
    - Navidrome: services/navidrome.md
    - qBittorrent: services/qbittorrent.md
    - SABnzbd: services/sabnzbd.md
    - Unpackerr: services/unpackerr.md
    - Matrix: services/matrix.md
    - PostgreSQL: services/postgresql.md
    - AdGuard Home: services/adguard.md
    - Monitoring: services/monitoring.md
    - Home Assistant: services/home-assistant.md
    - Satisfactory: services/satisfactory.md
    - LanCache: services/lancache.md
    - Nexus Registry: services/nexus.md
    - Woodpecker CI: services/woodpecker.md
  - Operations:
    - Deployment: operations/deployment.md
    - k3s Cluster: operations/k3s-cluster.md
    - Backups: operations/backups.md
    - Secrets: operations/secrets.md
    - Updates: operations/updates.md
  - Troubleshooting: troubleshooting.md
```

## Service Page Template

Each service page follows this structure:

```markdown
# Service Name

> One-line description

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace / VM `nas` (300) |
| **Access** | `https://sonarr.elysium.industries` |
| **Port** | 8989 |
| **Database** | PostgreSQL `sonarr_main`, `sonarr_log` on `db` VM |
| **Repo** | `jellybuntu-helm` → `clusters/jellybuntu/media/sonarr.yaml` |

## Key Config

(Non-obvious configuration notes — what's custom, what deviates from defaults)

## Common Operations

(Restart, logs, troubleshooting specific to this service)
```

Fields in the metadata table are included only when applicable (e.g., no Database row
for services without one).

## Key Page Content

### index.md

- One-sentence project description
- Service quick-reference table (name, URL, where it runs)
- Repo map with links to jellybuntu, jellybuntu-helm, jellybuntu-wiki
- "Start here" links

### architecture.md

- Mermaid diagram: Proxmox → VMs (dedicated + k3s) → services
- Hybrid model rationale
- k3s cluster topology (control, gpu, media, net, ops)
- Ingress flow: DNS → AdGuard rewrite → Traefik → service
- Data flow: NAS → NFS → mounts/PVCs → services
- Cross-repo relationship

### troubleshooting.md

- k3s / Flux issues
- NFS / storage issues
- DNS / cert issues
- Service-specific gotchas (brief, linking to service pages)

### operations/k3s-cluster.md

- Flux GitOps workflow (push → reconcile)
- Common kubectl commands
- Node operations (drain, cordon, GPU taints)
- MetalLB VIP / ingress
- Adding a new service to k3s

## Conventions

- Cross-repo links: absolute GitHub URLs (`https://github.com/SilverDFlame/jellybuntu/blob/main/...`)
- Internal links: relative (`architecture.md`, `services/sonarr.md`)
- Code blocks: language tags required (`bash`, `yaml`, `text`)
- Line length: max 120 chars (code blocks/tables excluded)

## Source Repositories

| Repo | Local Path | Purpose |
|------|-----------|---------|
| jellybuntu | `~/coding/jellybuntu` (feature/k3s-service-migration branch) | Ansible/Terraform IaC |
| jellybuntu-helm | `~/coding/jellybuntu-helm` | Flux GitOps k3s manifests |
| jellybuntu-wiki | `~/coding/jellybuntu-wiki` | This wiki (MkDocs) |
