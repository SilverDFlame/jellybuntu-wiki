# Jellybuntu Infrastructure Wiki

Operator-facing documentation for the Jellybuntu homelab. Built with MkDocs + Material,
deployed via Woodpecker CI to the NAS.

**Related repositories:**

- [SilverDFlame/jellybuntu](https://github.com/SilverDFlame/jellybuntu) — Ansible / OpenTofu / Packer IaC
- [SilverDFlame/jellybuntu-helm](https://github.com/SilverDFlame/jellybuntu-helm) — Flux GitOps manifests

> **Note:** page-level content is currently being refreshed to match the live cluster
> state. Architecture and topology pages are accurate; per-service pages may lag the
> live config until the in-progress refresh lands.

## Reading the docs

- **Hosted:** <https://docs.elysium.industries> (k3s Traefik → NAS nginx; direct fallback <http://nas.discus-moth.ts.net:8082>)
- **Local:** `mkdocs serve` → <http://localhost:8000>

## Documentation tree

```text
docs/
├── index.md                # Service dashboard + repo map + quick links
├── architecture.md         # Hybrid VM + k3s design, network/storage diagrams
├── troubleshooting.md      # Common-issue catalog (single page)
├── infrastructure/         # Platform-level
│   ├── vms.md              # VM inventory + resource sizing
│   ├── networking.md       # VLANs, Tailscale, Cilium, ingress
│   ├── storage.md          # Btrfs NAS, NFS exports, k3s PV/PVC
│   └── gpu.md              # NVIDIA device plugin, taints, Jellyfin/Tdarr GPU sharing
├── operations/             # Day-2
│   ├── deployment.md       # Phased Ansible deploy
│   ├── k3s-cluster.md      # Cluster topology, node roles
│   ├── k3s-namespaces.md   # Namespace-by-namespace breakdown
│   ├── helm-repo.md        # Flux GitOps workflow (sibling jellybuntu-helm)
│   ├── flux-image-automation.md # Flux image automation (ImagePolicy + auto-pin)
│   ├── secrets.md          # SOPS + age workflow
│   ├── backups.md          # Snapshot + restore procedures
│   └── updates.md          # OS, k3s, Flux, app upgrades
└── services/               # One page per workload (~21 pages)
    ├── jellyfin.md, tdarr.md
    ├── sonarr.md, radarr.md, lidarr.md, prowlarr.md, bazarr.md
    ├── sabnzbd.md, qbittorrent.md, jellyseerr.md, navidrome.md
    ├── unpackerr.md, matrix.md
    ├── home-assistant.md, satisfactory.md
    ├── adguard.md, postgresql.md, nexus.md
    ├── monitoring.md, lancache.md, woodpecker.md
    └── ...
```

## Service page template

Every service page follows the same skeleton:

```markdown
# Service Name

> One-line description

| Field | Value |
|-------|-------|
| **Runs on** | k3s `<namespace>` / VM `<host>` (`<vmid>`) |
| **Access** | `https://<service>.elysium.industries` |
| **Port** | `<port>` |
| **Database** | PostgreSQL `<db>` on `db` VM (if applicable) |
| **Manifest** | `jellybuntu-helm` → `clusters/jellybuntu/<layer>/<file>.yaml` |

## Key Config
## Common Operations
```

Omit rows that don't apply.

## Local development

```bash
pip install -r requirements.txt
mkdocs serve            # preview at http://localhost:8000
mkdocs build --strict   # CI uses this
pre-commit run --all-files
```

## Markdown style (pre-commit enforced)

| Rule | Constraint |
|------|------------|
| MD013 | Max 200 chars/line (code blocks + tables excluded) |
| MD031 | Blank lines around fenced code blocks |
| MD032 | Blank lines around lists |
| MD040 | Code fences need language tags (`bash`, `yaml`, `text`) |

Relaxed: MD024 (`siblings_only`), MD033/MD034/MD041 disabled.

## Cross-repository references

External code links → absolute GitHub URLs (relative paths don't resolve outside this repo):

```markdown
[`roles/jellyfin/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/jellyfin)
[`clusters/jellybuntu/media/`](https://github.com/SilverDFlame/jellybuntu-helm/tree/main/clusters/jellybuntu/media)
```

Internal wiki links → relative:

```markdown
[Architecture](architecture.md)
[Sonarr](services/sonarr.md)
```

## CI/CD

Built and deployed by Woodpecker CI on push to `main` (when `docs/`, `mkdocs.yml`, or
`requirements.txt` changes):

1. `build-docs`: `mkdocs build --strict`
2. `deploy-docs`: rsync to `nas.discus-moth.ts.net:/opt/docs/site/`

**Secret required:** `ssh_ci_private_key` (Woodpecker secret, not in repo).

## Git workflow

```bash
git checkout -b docs/your-improvement
# edit
git commit -m "docs: <what changed>"
git push -u origin docs/your-improvement
gh pr create
```

Branch prefixes: `docs/`, `fix/`, `feature/`.

## License

MIT — see [LICENSE](LICENSE).

## Acknowledgments

[MkDocs](https://www.mkdocs.org/) · [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/).
