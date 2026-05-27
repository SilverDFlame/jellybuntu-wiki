# Flux Image Automation

> Auto-pins cluster images to immutable upstream tags via GitOps. 12 images tracked.

**Repo**: [SilverDFlame/jellybuntu-helm](https://github.com/SilverDFlame/jellybuntu-helm)
**Chart**: [`charts/image-automation/`](https://github.com/SilverDFlame/jellybuntu-helm/tree/main/charts/image-automation)
**Config**: [`clusters/jellybuntu/infrastructure/image-automation/release.yaml`](https://github.com/SilverDFlame/jellybuntu-helm/blob/main/clusters/jellybuntu/infrastructure/image-automation/release.yaml)

## How It Works

Flux's `image-reflector` and `image-automation` controllers scan upstream tags and
write resolved pins back into Git. The chart renders one `ImageRepository` +
`ImagePolicy` per entry in `release.yaml` `values.images`, plus a single
`ImageUpdateAutomation` (`jellybuntu-helm-images`).

- **Discovery** routes through the Nexus docker-group `192.168.30.15:5001` (insecure,
  no TLS), cooldown-aged 7d. Pod pulls still hit `lscr.io`/`ghcr.io`/`docker.io`
  directly; k3s containerd mirrors transparently to the same Nexus endpoint.
- **Write-back** pushes resolved tags **direct to `main`** every 30m via SSH deploy
  key `flux-image-automation` (id 150082818, `read_only: false`) through the
  `jellybuntu-helm-write` GitRepository. There is no PAT and no branch protection on
  this repo — `pushBranch: main` plus the deploy key is the entire mechanism. The
  chart's `pushBranch:` is the only gate.
- **Update strategy** is `Setters`: Flux rewrites the `tag:` value wherever a
  `$imagepolicy` marker comment points at it.

## Two Policy Types

| Policy | Orders by | When to use |
|--------|-----------|-------------|
| **numerical** (default) | integer in `extract` (LSIO `-ls<build>`) | Only when the build counter is monotonic across versions |
| **semver** | version in `extract`, needs `semverRange` | Non-LSIO upstreams, and any LSIO image whose build counter resets |

Default LSIO pattern (in chart `values.yaml`):

```yaml
filterPattern: '^(?P<version>\d+(\.\d+){1,3})-ls(?P<build>\d+)$'
extract: '$build'
policyOrder: asc
```

### Major-pin discipline

Every semver image pins the major (`>=X.0.0 <X+1.0.0`) so breaking upgrades are
human-gated, not auto-pulled. Exceptions:

- **navidrome** is 0.x — minor is the breaking digit, so it is pinned patch-only
  (`>=0.61.0 <0.62.0`).
- **jellyfin** is minor-capped (`<10.12.0`) to gate the next potential DB migration
  (see [jellybuntu#58](https://github.com/SilverDFlame/jellybuntu/issues/58)).

## Current Roster

12 images automated. Resolved tags drift continuously — read live pins with
`flux get image policy -A` rather than trusting any static list.

| Image | Policy | Range / pattern note |
|-------|--------|----------------------|
| sonarr | numerical | LSIO `-ls<build>` (default pattern) |
| radarr | numerical | LSIO |
| lidarr | numerical | LSIO |
| prowlarr | numerical | LSIO |
| deluge | numerical | LSIO |
| bazarr | numerical | LSIO, `v`-prefix override pattern |
| navidrome | semver | `>=0.61.0 <0.62.0` (0.x, patch-only) |
| seer | semver | `>=3.0.0 <4.0.0`, `v`-prefix |
| byparr | semver | `>=2.0.0 <3.0.0` |
| tdarr | semver | `>=2.0.0 <3.0.0`, leading-zero patch |
| jellyfin | semver | `>=10.11.0 <10.12.0`, `ubuXXXX-ls` infix |
| recyclarr | semver | `>=8.0.0 <9.0.0` (8.x migration verified, [jellybuntu-helm#83](https://github.com/SilverDFlame/jellybuntu-helm/pull/83)) |

**Excluded**: **gluetun** — VPN sidecar, kept manual since a bad pull risks a torrent
IP leak.

## Add a New Image

1. Add an entry to `release.yaml` `values.images` (`repository` = Nexus path;
   add `filterPattern`/`extract`/`policy`/`semverRange` as the tag scheme needs).
2. Add the policy marker to the HelmRelease `tag:` line:

   ```yaml
   tag: v1.5.6-ls349 # {"$imagepolicy": "flux-system:bazarr:tag"}
   ```

3. **Validate the regex against live tags before merge** — see Troubleshooting.
4. PR → merge → Flux resolves and pushes the pin to `main` within ~30m.

Validate a pattern offline before committing:

```bash
skopeo list-tags docker://lscr.io/linuxserver/bazarr | \
  grep -E '^v[0-9]+(\.[0-9]+){1,3}-ls[0-9]+$'
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `version list argument cannot be empty` | `filterPattern` matched **zero** tags (scheme differs from default LSIO regex) | Per-image `filterPattern` override — caught for bazarr (`v` prefix), jellyfin (`ubuXXXX` infix) |
| numerical picks a stale older version | LSIO `-ls<build>` counter reset at a major rebase (jellyfin 10.10.7-ls80 → 10.11.0-ls1 at the EF Core migration) | Switch that image to `semver` policy |
| `2.75.01` parses oddly (tdarr) | Leading-zero patch is invalid semver | Masterminds/semver (Flux) coerces `2.75.01` → `2.75.1`, so it works; if a future Flux tightens parsing, fall back to numerical-on-minor |
| semver resolves a version with multiple builds indeterminately | semver orders by version only (e.g. jellyfin 10.11.6 ls17..ls25) | App version is preserved; exact build is not — acceptable for these images |

Inspect controller state:

```bash
flux get image repository -A   # discovery / scan status
flux get image policy -A       # current resolved pins
flux get image update -A       # write-back automation status
```

## See Also

- [Helm Repo Layout](helm-repo.md) — chart structure, SOPS, app-template notes
- [Updates](updates.md) — manual update workflow for non-automated images
- jellybuntu [#138](https://github.com/SilverDFlame/jellybuntu/issues/138) (umbrella),
  [#58](https://github.com/SilverDFlame/jellybuntu/issues/58) (jellyfin perf),
  [#196](https://github.com/SilverDFlame/jellybuntu/issues/196) (deferred L3 Kyverno / L4 Trivy)
