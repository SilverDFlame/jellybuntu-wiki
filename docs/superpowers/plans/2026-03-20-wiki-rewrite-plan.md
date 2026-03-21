# Jellybuntu Wiki Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stale wiki with 34 pages documenting the final-state hybrid VM + k3s
infrastructure.

**Architecture:** Delete all existing docs, rewrite mkdocs.yml nav, create new pages organized
as infrastructure/services/operations. Content is sourced from the jellybuntu repo
(feature/k3s-service-migration branch) and jellybuntu-helm repo.

**Tech Stack:** MkDocs Material, Markdown, Mermaid diagrams

**Spec:** `docs/superpowers/specs/2026-03-20-wiki-rewrite-design.md`

**Source repos for content:**

- `~/coding/jellybuntu` (branch: feature/k3s-service-migration) — Ansible/Terraform IaC
- `~/coding/jellybuntu-helm` — Flux GitOps k3s manifests

**Note:** Task 1 deletes old wiki content. Old pages remain available via
`git show HEAD~N:docs/path/to/old-file.md` if needed as supplementary source during
page creation.

---

## Task 1: Delete old content and broken CI

**Files:**

- Delete: all 127 markdown files under `docs/` EXCEPT `docs/superpowers/specs/2026-03-20-wiki-rewrite-design.md`
  and this plan file
- Delete: `.github/workflows/doc-sync-check.yml`
- Delete: `.github/sync-mapping.yml`

- [ ] **Step 1: Delete all old docs content**

```bash
# Delete all docs subdirectories except superpowers (has our spec + plan)
rm -rf docs/archive docs/configuration docs/deployment docs/development \
       docs/maintenance docs/plans docs/reference docs/troubleshooting

# Delete root-level doc files (index, architecture, quickstart, CLAUDE.md)
rm -f docs/index.md docs/architecture.md docs/quickstart.md docs/CLAUDE.md
```

- [ ] **Step 2: Delete broken CI files**

```bash
rm -f .github/workflows/doc-sync-check.yml .github/sync-mapping.yml
```

- [ ] **Step 3: Verify only spec/plan remain**

```bash
find docs/ -name "*.md" | sort
```

Expected: only the spec and plan files under `docs/superpowers/`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: delete stale wiki content and broken doc-sync CI

Removes all 127 doc files documenting the old Docker/VM architecture.
Removes doc-sync-check GitHub Action that never worked.
Preserves spec and plan for the rewrite."
```

---

## Task 2: Update mkdocs.yml

**Files:**

- Modify: `mkdocs.yml`

- [ ] **Step 1: Update site_description, remove exclude_docs, update validation**

Change line 2 from:

```yaml
site_description: Homelab infrastructure automation documentation - Ansible, Proxmox, and Podman
```

to:

```yaml
site_description: Homelab infrastructure documentation - Proxmox, k3s, Ansible, and Flux
```

Remove lines 5-6:

```yaml
exclude_docs: |
  archive/
```

Update the validation comment (leave `omitted_files: info` for now — Task 14 changes it
to `warn` after moving spec/plan files out of `docs/`):

```yaml
  omitted_files: info  # Many files intentionally not in nav (research, plans, etc.)
```

to:

```yaml
  omitted_files: info  # Changed to warn in Task 14 after spec/plan files move out of docs/
```

- [ ] **Step 2: Replace the nav section**

Replace the entire `nav:` block (lines 89-129) with:

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

- [ ] **Step 3: Commit**

```bash
git add mkdocs.yml
git commit -m "chore: rewrite mkdocs.yml nav for new wiki structure

Update site_description for k3s era, remove archive exclusion,
replace nav with new infrastructure/services/operations layout."
```

---

## Task 3: Update root CLAUDE.md

**Files:**

- Modify: `CLAUDE.md`

- [ ] **Step 1: Rewrite CLAUDE.md**

Replace the entire file. Key changes:

- Update "About" to reference k3s + Flux alongside Ansible
- Update local clone path from `~/coding/mirrors/jellybuntu/` to `~/coding/jellybuntu`
  (feature/k3s-service-migration branch)
- Add jellybuntu-helm repo reference at `~/coding/jellybuntu-helm`
- Replace directory structure with new layout (infrastructure/, services/, operations/)
- Absorb authoring conventions from deleted `docs/CLAUDE.md`:
  cross-repo URL patterns, internal link conventions, markdown style guide, linting rules
- Remove reference to `docs/CLAUDE.md`
- Keep: development workflow (mkdocs serve, build --strict, pre-commit), CI/CD section,
  git workflow, quick reference table

- [ ] **Step 2: Verify no broken references**

```bash
grep -n "docs/CLAUDE.md\|archive/\|quickstart\|configuration/\|deployment/" CLAUDE.md
```

Expected: no matches.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: rewrite CLAUDE.md for new wiki structure

Absorb authoring conventions from deleted docs/CLAUDE.md.
Update repo paths and directory structure for k3s era."
```

---

## Task 4: Create docs/index.md

**Files:**

- Create: `docs/index.md`

**Content sources:**

- `~/coding/jellybuntu/infrastructure/terraform/vms.tf` — VM definitions, IPs
- `~/coding/jellybuntu/services/configs/adguard-vars.yml` — DNS rewrites (service URLs)
- `~/coding/jellybuntu-helm/clusters/jellybuntu/` — k3s namespace assignments

- [ ] **Step 1: Create index.md**

Content outline:

```markdown
# Jellybuntu

> Hybrid Proxmox VM + k3s homelab on an AMD EPYC 7313P

## Services

(Table with columns: Service, URL, Runs On)
(All services from the spec, with their access URLs and VM/k3s namespace)

## Repositories

(Table linking to jellybuntu, jellybuntu-helm, jellybuntu-wiki with one-line descriptions)

## Start Here

- [Architecture](architecture.md) — system design and topology
- [Deployment](operations/deployment.md) — phase-based deployment guide
- [k3s Cluster](operations/k3s-cluster.md) — Flux GitOps workflow
```

Populate the services table by reading the source repos for accurate URLs, ports, and
namespace assignments. The DNS rewrites in `adguard-vars.yml` have all `*.elysium.industries`
URLs. Cross-reference with Helm manifests for namespace placement.

- [ ] **Step 2: Validate renders**

```bash
mkdocs serve &
# Check http://localhost:8000 renders correctly
kill %1
```

- [ ] **Step 3: Commit**

```bash
git add docs/index.md
git commit -m "docs: add index.md service dashboard"
```

---

## Task 5: Create docs/architecture.md

**Files:**

- Create: `docs/architecture.md`

**Content sources:**

- `~/coding/jellybuntu/infrastructure/terraform/vms.tf` — VM topology, VLANs
- `~/coding/jellybuntu/CLAUDE.md` and `~/coding/jellybuntu/RECENT_CHANGES.md` — architecture description
- `~/coding/jellybuntu-helm/README.md` — k3s cluster structure, dependency chain

- [ ] **Step 1: Create architecture.md**

Content outline:

```markdown
# Architecture

## Overview
(2-3 sentences: hybrid Proxmox VM + k3s, EPYC 7313P, 15 VMs, 4 VLANs)

## System Diagram
(Mermaid: Proxmox host → VMs split into dedicated VMs + k3s cluster nodes → services)

## k3s Cluster Topology
(Table: node name, VMID, role, what runs on it)
- k8s-control (410): control plane
- k8s-gpu (411): Jellyfin, Tdarr (GPU workloads)
- k8s-media (412): arr stack, download clients
- k8s-net (413): MetalLB, Traefik ingress
- k8s-ops (414): Synapse, monitoring, CI

## Dedicated VMs
(Table: VM, purpose, why not k3s)
- jellyfin (400) — being migrated to k3s
- nas (300) — storage backend, must be independent
- db (415) — PostgreSQL, accessed by k3s pods directly
- home-assistant, satisfactory, lancache, monitoring, automation, unifi, reverse-proxy

## Ingress Flow
(Mermaid: Internet → Cloudflare → AdGuard DNS rewrite → Traefik VIP 192.168.30.200 → k3s pod)

## Data Flow
(Mermaid: NAS Btrfs → NFS export → VM mounts / k8s PVCs → services)

## Cross-Repository Relationship
(Diagram or table: jellybuntu provisions VMs → jellybuntu-helm deploys k3s workloads → wiki documents)
```

- [ ] **Step 2: Commit**

```bash
git add docs/architecture.md
git commit -m "docs: add architecture overview with topology diagrams"
```

---

## Task 6: Create infrastructure pages

**Files:**

- Create: `docs/infrastructure/vms.md`
- Create: `docs/infrastructure/networking.md`
- Create: `docs/infrastructure/storage.md`
- Create: `docs/infrastructure/gpu.md`

**Content sources:**

- `~/coding/jellybuntu/infrastructure/terraform/vms.tf` — all VM definitions (lines 1-end)
- `~/coding/jellybuntu/infrastructure/terraform/vms.tf:7-16` — VLAN definitions
- `~/coding/jellybuntu/services/configs/adguard-vars.yml` — DNS rewrites, blocklists
- `~/coding/jellybuntu/roles/traefik_proxy/` — Traefik config, TLS
- `~/coding/jellybuntu/roles/btrfs_storage/`, `roles/nfs_server/`, `roles/nfs_client/` — storage
- `~/coding/jellybuntu/host_vars/nas.yml` — NFS exports, Btrfs config
- `~/coding/jellybuntu/roles/k3s_gpu_node/` — GPU passthrough, NVIDIA setup
- `~/coding/jellybuntu/host_vars/k8s-gpu.yml` — GPU node config
- `~/coding/jellybuntu/roles/proxmox_host/tasks/nfs_export.yml` — NVMe NFS for PVCs
- `~/coding/jellybuntu-helm/clusters/jellybuntu/net/metallb-config.yaml` — MetalLB IP pool

- [ ] **Step 1: Create docs/infrastructure/ directory and vms.md**

`vms.md` content: Full VM inventory table (VMID, hostname, IP, VLAN, vCPU, RAM, disk,
purpose, boot order). Source all values from `vms.tf`. Include the VLAN assignment table.

- [ ] **Step 2: Create networking.md**

Content: VLAN table (ID, CIDR, gateway, purpose), DNS chain (AdGuard → Unbound → recursive),
DNS rewrites (all `*.elysium.industries` entries), Traefik ingress (k3s MetalLB VIP
192.168.30.200 + VM reverse-proxy for Jellyfin), TLS (Let's Encrypt wildcard, Cloudflare
DNS-01), Tailscale overlay network.

- [ ] **Step 3: Create storage.md**

Content: Btrfs RAID1 on NAS, NFS exports table (path, consumers, options), NVMe-backed NFS
for k8s PVCs, mount paths (`/mnt/data/` on VMs, PVC mounts in k8s), direct-IP rationale
(192.168.30.15 vs Tailscale for NFS performance), UID/GID squashing (3000:3000).

- [ ] **Step 4: Create gpu.md**

Content: Proxmox GPU passthrough to k8s-gpu VM (411), NVIDIA device plugin in k3s,
time-slicing ConfigMap (2 replicas: Jellyfin + Tdarr), containerd runtime config,
node taint for GPU scheduling.

- [ ] **Step 5: Commit**

```bash
git add docs/infrastructure/
git commit -m "docs: add infrastructure pages (VMs, networking, storage, GPU)"
```

---

## Task 7: Create k3s service pages (gpu namespace)

**Files:**

- Create: `docs/services/jellyfin.md`
- Create: `docs/services/tdarr.md`

**Content sources:**

- `~/coding/jellybuntu-helm/clusters/jellybuntu/gpu/jellyfin.yaml` — Jellyfin k8s manifest
- `~/coding/jellybuntu-helm/clusters/jellybuntu/gpu/tdarr.yaml` — Tdarr k8s manifest
- `~/coding/jellybuntu-helm/clusters/jellybuntu/gpu/ingress.yaml` — Traefik IngressRoute
- `~/coding/jellybuntu-helm/clusters/jellybuntu/gpu/nfs-media-pv.yaml` — NFS PV for media
- `~/coding/jellybuntu/host_vars/k8s-gpu.yml` — GPU config

Follow the service page template from the spec. Each page has: metadata table (Runs on,
Access URL, Port, Database if applicable, Repo path), Key Config section, Common Operations
section.

- [ ] **Step 1: Read source manifests**

Read the Helm/kustomize files listed above to get accurate ports, resource limits, volume
mounts, and ingress routes.

- [ ] **Step 2: Create jellyfin.md**

- [ ] **Step 3: Create tdarr.md**

- [ ] **Step 4: Commit**

```bash
git add docs/services/jellyfin.md docs/services/tdarr.md
git commit -m "docs: add Jellyfin and Tdarr service pages (gpu namespace)"
```

---

## Task 8: Create k3s service pages (media namespace)

**Files:**

- Create: `docs/services/sonarr.md`
- Create: `docs/services/radarr.md`
- Create: `docs/services/prowlarr.md`
- Create: `docs/services/bazarr.md`
- Create: `docs/services/lidarr.md`
- Create: `docs/services/jellyseerr.md`
- Create: `docs/services/navidrome.md`
- Create: `docs/services/qbittorrent.md`
- Create: `docs/services/sabnzbd.md`
- Create: `docs/services/unpackerr.md`

**Content sources:**

- `~/coding/jellybuntu-helm/clusters/jellybuntu/media/*.yaml` — all media namespace manifests
- `~/coding/jellybuntu/host_vars/db.yml` — PostgreSQL database names
- `~/coding/jellybuntu/roles/postgresql/tasks/databases.yml` — database definitions

Follow the service page template. For services with PostgreSQL backends (Sonarr, Radarr,
Lidarr), include the Database field. For download clients (qBittorrent, SABnzbd), note
VPN/Gluetun config if present in the manifests.

- [ ] **Step 1: Read media namespace manifests**

Read all files in `~/coding/jellybuntu-helm/clusters/jellybuntu/media/` to get accurate
service details.

- [ ] **Step 2: Create all 10 service pages**

Create each following the template. These are straightforward — most are simple arr-stack
services with the same pattern (k3s media namespace, Traefik ingress, NFS media mount).

- [ ] **Step 3: Commit**

```bash
git add docs/services/sonarr.md docs/services/radarr.md docs/services/prowlarr.md \
        docs/services/bazarr.md docs/services/lidarr.md docs/services/jellyseerr.md \
        docs/services/navidrome.md docs/services/qbittorrent.md docs/services/sabnzbd.md \
        docs/services/unpackerr.md
git commit -m "docs: add media namespace service pages (10 services)"
```

---

## Task 9: Create k3s service pages (ops namespace)

**Files:**

- Create: `docs/services/matrix.md`
- Create: `docs/services/monitoring.md`
- Create: `docs/services/woodpecker.md`

**Content sources:**

- `~/coding/jellybuntu-helm/clusters/jellybuntu/ops/` — ops namespace manifests
- `~/coding/jellybuntu/roles/postgresql/tasks/databases.yml` — synapse database
- `~/coding/jellybuntu/host_vars/monitoring.yml` if present — monitoring VM config

Matrix page covers Synapse + synapse-admin + lk-jwt as a group (they're one logical service).
Monitoring page covers both k3s-hosted Prometheus/Grafana and VM-based node exporters.
Woodpecker covers CI/CD pipelines.

- [ ] **Step 1: Read ops namespace manifests**

- [ ] **Step 2: Create matrix.md, monitoring.md, woodpecker.md**

- [ ] **Step 3: Commit**

```bash
git add docs/services/matrix.md docs/services/monitoring.md docs/services/woodpecker.md
git commit -m "docs: add ops namespace service pages (Matrix, monitoring, Woodpecker)"
```

---

## Task 10: Create VM-based service pages

**Files:**

- Create: `docs/services/postgresql.md`
- Create: `docs/services/adguard.md`
- Create: `docs/services/home-assistant.md`
- Create: `docs/services/satisfactory.md`
- Create: `docs/services/lancache.md`
- Create: `docs/services/nexus.md`

**Content sources:**

- `~/coding/jellybuntu/host_vars/db.yml` — PostgreSQL config
- `~/coding/jellybuntu/roles/postgresql/` — PostgreSQL role (install, databases, templates)
- `~/coding/jellybuntu/services/configs/adguard-vars.yml` — AdGuard config
- `~/coding/jellybuntu/host_vars/nas.yml` — NAS services (AdGuard, Nexus, Unbound)
- `~/coding/jellybuntu/roles/home_assistant/` if present
- `~/coding/jellybuntu/host_vars/home-assistant.yml` if present
- `~/coding/jellybuntu/host_vars/satisfactory-server.yml` if present
- `~/coding/jellybuntu/roles/satisfactory/` if present
- `~/coding/jellybuntu/host_vars/lancache.yml` if present
- `~/coding/jellybuntu/roles/nexus/` if present

These are VM-based services. The "Runs on" field references the VM name/VMID instead of a
k3s namespace. The "Repo" field references `jellybuntu` roles/playbooks instead of
`jellybuntu-helm`.

- [ ] **Step 1: Read VM host_vars and roles for each service**

- [ ] **Step 2: Create all 6 service pages**

PostgreSQL is the most detailed — list all databases served, how k8s pods connect
(direct IP 192.168.30.16:5432), and the pg_hba.conf allowlist.

AdGuard covers DNS rewrites, blocklists, and Unbound upstream.

- [ ] **Step 3: Commit**

```bash
git add docs/services/postgresql.md docs/services/adguard.md \
        docs/services/home-assistant.md docs/services/satisfactory.md \
        docs/services/lancache.md docs/services/nexus.md
git commit -m "docs: add VM-based service pages (PostgreSQL, AdGuard, HA, Satisfactory, LanCache, Nexus)"
```

---

## Task 11: Create operations pages

**Files:**

- Create: `docs/operations/deployment.md`
- Create: `docs/operations/k3s-cluster.md`
- Create: `docs/operations/backups.md`
- Create: `docs/operations/secrets.md`
- Create: `docs/operations/updates.md`

**Content sources:**

- `~/coding/jellybuntu/playbooks/README.md` — playbook overview and phase descriptions
- `~/coding/jellybuntu/playbooks/phases/*.yml` — phase definitions
- `~/coding/jellybuntu/playbooks/infrastructure/k3s-cluster.yml` — k3s bootstrap
- `~/coding/jellybuntu-helm/README.md` — Flux workflow, kubectl commands, adding services
- `~/coding/jellybuntu/roles/btrfs_snapshots/` — backup config
- `~/coding/jellybuntu/group_vars/all.sops.yaml` — encrypted secrets (structure only)
- `~/coding/jellybuntu/roles/common/` — update procedures

- [ ] **Step 1: Create deployment.md**

Phase-based deployment reference. Table of phases 1-5 with what each does, which playbook
runs it, and prerequisites. Reference jellybuntu repo playbooks via GitHub URLs.

- [ ] **Step 2: Create k3s-cluster.md**

Flux GitOps workflow (push to jellybuntu-helm → Flux reconciles). Common kubectl commands
for this cluster. Node operations (drain, cordon, GPU node taints). MetalLB VIP overview.
How to add a new service (step-by-step). Reference jellybuntu-helm repo.

- [ ] **Step 3: Create backups.md**

Btrfs snapshot procedures, recovery steps. Brief — reference the btrfs_snapshots role.

- [ ] **Step 4: Create secrets.md**

SOPS/age encryption overview. How to edit encrypted files. Key rotation procedure.
Reference the encrypted file at `group_vars/all.sops.yaml`.

- [ ] **Step 5: Create updates.md**

OS patching (apt upgrade via Ansible common role). Service updates: for k3s services, update
image tag in jellybuntu-helm and push (Flux handles it). For VM services, update via Ansible
playbook. Flux reconciliation commands.

- [ ] **Step 6: Commit**

```bash
git add docs/operations/
git commit -m "docs: add operations pages (deployment, k3s, backups, secrets, updates)"
```

---

## Task 12: Create troubleshooting.md

**Files:**

- Create: `docs/troubleshooting.md`

- [ ] **Step 1: Create troubleshooting.md**

Single page organized by headers:

```markdown
# Troubleshooting

## k3s / Flux
- Pod stuck in CrashLoopBackOff / ImagePullBackOff
- Flux reconciliation stuck or failing
- GPU not detected by pod (device plugin, runtime, taint)

## NFS / Storage
- NFS mount failure (check NAS IP 192.168.30.15, exports, firewall)
- Permission denied on media files (UID/GID 3000:3000 squashing)
- PVC not bound (check NFS provisioner, StorageClass)

## DNS / Certificates
- Service not reachable via *.elysium.industries (check AdGuard rewrites)
- TLS cert expired (check Traefik ACME, Cloudflare API token)
- DNS resolution failing (check Unbound, AdGuard upstream)

## Common Service Issues
(Brief per-service gotchas with links to the relevant service page)
```

Each entry: symptom, likely cause, fix command. Keep it terse.

- [ ] **Step 2: Commit**

```bash
git add docs/troubleshooting.md
git commit -m "docs: add troubleshooting page"
```

---

## Task 13: Validate and final build

- [ ] **Step 1: Run mkdocs build --strict**

```bash
mkdocs build --strict
```

Expected: clean build, no warnings about missing pages or broken links.

- [ ] **Step 2: Run pre-commit checks**

```bash
pre-commit run --all-files
```

Expected: all checks pass (trailing whitespace, YAML, markdownlint).

- [ ] **Step 3: Fix any issues found**

Address lint errors or broken links from steps 1-2.

- [ ] **Step 4: Final commit if fixes were needed**

```bash
git add -A
git commit -m "fix: address lint and build issues"
```

---

## Task 14: Clean up spec/plan files

The spec and plan files under `docs/superpowers/` are not part of the wiki nav and would
trigger `omitted_files: warn` in strict mode.

- [ ] **Step 1: Move spec and plan out of docs/**

```bash
mkdir -p superpowers/specs superpowers/plans
mv docs/superpowers/specs/2026-03-20-wiki-rewrite-design.md superpowers/specs/
mv docs/superpowers/plans/2026-03-20-wiki-rewrite-plan.md superpowers/plans/
rm -rf docs/superpowers
```

- [ ] **Step 2: Update mkdocs.yml omitted_files to warn**

Change in `mkdocs.yml`:

```yaml
  omitted_files: info  # Changed to warn in Task 14 after spec/plan files move out of docs/
```

to:

```yaml
  omitted_files: warn  # All docs should be in nav
```

- [ ] **Step 3: Re-validate build**

```bash
mkdocs build --strict
```

Expected: clean build, no warnings.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: move spec/plan files out of docs/, enable omitted_files: warn"
```
