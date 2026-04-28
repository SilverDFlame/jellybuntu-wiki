# Tdarr Setup and Configuration Guide

Tdarr is an automated media transcoding and optimization system. It processes your media library to
standardize video codecs (H.265), reduce storage, and reduce Jellyfin transcoding load.

> **Deployment**: HelmRelease `tdarr` in the `gpu` namespace, pinned to k8s-gpu node.
> Managed via Flux GitOps — edit `clusters/jellybuntu/gpu/tdarr.yaml` in `jellybuntu-helm`.

## Deployment Results

**Initial test (November 2025)**: 13 successful transcodes overnight.

- Average compression: 40-50% file size reduction (H.264 → H.265)
- Sample: 556.9 MB → 321.7 MB (42%), 556.5 MB → 264.8 MB (52%)

## Overview

| Field | Value |
|-------|-------|
| Namespace | `gpu` |
| Node | k8s-gpu (192.168.30.41) |
| Image | `ghcr.io/haveagitgat/tdarr:2.68.01` |
| WebUI Port | 8265 |
| Server Port | 8266 |
| URL | https://tdarr.elysium.industries (IP restricted: 192.168.30.0/24 + 100.64.0.0/10) |
| GPU | GTX 1080, time-sliced (1 virtual GPU shared with Jellyfin) |
| Mode | Single container with internal node (`internalNode=true`) |

**Why single container?** Using `internalNode=true` avoids the startup race condition that occurs
when running separate `tdarr` + `tdarr_node` containers in the same pod.

## Storage

| Volume | Type | Host Path / Claim | Container Path |
|--------|------|-------------------|----------------|
| server-data | PVC 2 Gi (nfs-client) | — | `/app/server` |
| configs | PVC 1 Gi (nfs-client) | — | `/app/configs` |
| media | PVC `nfs-media-gpu` (1 Ti) | — | `/data` |
| transcode-cache | hostPath | `/mnt/transcode-cache/tdarr` on k8s-gpu | `/temp` |

**In Tdarr UI**: Always use `/temp` for cache path — that is the container path for the RAM disk.

### RAM Disk (Transcode Cache)

The hostPath `/mnt/transcode-cache/tdarr` on k8s-gpu is a tmpfs RAM disk. Using RAM for
transcode cache prevents SSD wear from constant read/write during transcoding.

| Context | Path |
|---------|------|
| k8s-gpu node | `/mnt/transcode-cache/tdarr` |
| Tdarr container | `/temp` |

## Resources

| | Memory | GPU |
|-|--------|-----|
| Requests | 4 Gi | 1 |
| Limits | 8 Gi | 1 |

Node selector: `jellybuntu.io/role: gpu`

The 8 Gi limit is required for 4K HDR transcoding — lower limits cause OOM kills.

## Operations

```bash
# Logs
kubectl logs -n gpu deployment/tdarr -f

# Restart
kubectl rollout restart deployment/tdarr -n gpu

# Force Flux reconcile
flux reconcile helmrelease tdarr -n gpu
```

## Config Changes

1. Edit `clusters/jellybuntu/gpu/tdarr.yaml` in `jellybuntu-helm`
2. Open PR → merge to `main`
3. Flux reconciles automatically

## Initial Configuration

### 1. Access Web UI

Navigate to https://tdarr.elysium.industries (requires Tailscale or local 192.168.30.0/24 access).

### 2. Configure Libraries

Navigate to **Libraries** tab. Click a library to configure.

**TV Shows Library** (Source tab):

- Source: `/data/media/tv`
- Toggles to **ENABLE**: Folder Watch, Process Library, Transcodes, Health Checks, Scan on Start
- Toggles to **DISABLE**: Closed Caption Check, Directory Library
- Scanner: Run hourly scan ON, File scanner threads: 1
- Folder watch interval: **30 seconds**, Use file system events: **OFF** (NFS requires polling)

**Movies Library** (Source tab):

- Source: `/data/media/movies`
- Same toggle and scanner settings as TV Shows

> **NFS note**: Keep "Use file system events" OFF — inotify doesn't work over NFS. The 30-second
> polling interval handles detection of new files.

### 3. Configure Transcode Settings

Navigate to **Options** → **Transcode Options**:

- Concurrent Transcodes: **1** (start conservatively)
- Priority: **Low**
- Cache Path: `/temp` (container path for the RAM disk)
- Replace Original: **Yes** (after successful transcode)
- Keep Original: **No**
- Clean Transcode Cache: **Yes**

### 4. Create Transcode Flows

Tdarr uses "flows" (plugins) to define transcode operations.

For the complete production-tested flow configuration, see:
[docs/configuration/tdarr-flow-configuration.md](tdarr-flow-configuration.md)

**4-Branch Architecture** — handles all content types with HDR/SDR detection:

| Branch | 10-Bit | HDR Params | CRF |
|--------|--------|------------|-----|
| 4K HDR | Yes | Yes | 23 |
| 4K SDR | No | No | 23 |
| 1080p HDR | Yes | Yes | 21 |
| 1080p SDR | No | No | 21 |

**Critical requirements**:

- **Input File node** must be the first node in any flow (common failure point)
- **Check HDR Video** must BRANCH (not just detect) to route HDR/SDR correctly
- Follow the connection map exactly for branching flows
- Test with single files before enabling on full libraries

#### Recommended Starting Profile: H.265 Standardization

**Plugin Stack**:

1. **Check File**: Skip if already H.265
   - Plugin: `Check Video Codec`, Codec: `hevc`, Action: Skip if match

2. **Transcode to H.265**:
   - Plugin: `Transcode Video`, Output Codec: `hevc`, CRF: `23`, Preset: `medium`
   - Audio: `copy`, Container: `mkv`

3. **Remove Subtitle Tracks** (optional — only if you don't use subtitles)

#### Advanced Profile: 4K Optimization

1. **Check Resolution**: Only process 4K — Plugin: `Check Video Resolution`, `>=2160p`, skip if not match
2. **Transcode 4K**: Codec `hevc`, CRF `28`, Preset `slow`

### 5. Configure Node Workers

Navigate to **Nodes** → **K8sNode** to configure worker settings.

**GPU Worker Settings** (GTX 1080 NVENC):

| Setting | Recommended Value | Rationale |
|---------|-------------------|-----------|
| GPU Workers | **2** | NVENC artificial limit on unpatched consumer driver |
| CPU Workers | **0** | GPU handles encoding |
| Health Check CPU | **1** | Health checks don't use GPU |

**Performance with GTX 1080 NVENC**:

| Content Type | CPU-Only | GPU (NVENC) |
|--------------|----------|-------------|
| 4K HEVC → H.265 | ~0.3x realtime | 3-5x realtime |
| 4K H.264 → H.265 | ~0.5x realtime | 5-8x realtime |
| 1080p → H.265 | ~2x realtime | 15-20x realtime |

#### Optional: Unlock NVENC Stream Limit

```bash
# Run on k8s-gpu node — removes 2-stream artificial cap
ssh -i ~/.ssh/ansible_homelab ansible@192.168.30.41 \
  "sudo bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch.sh)\""
```

After patching, increase GPU workers to 3-4.

### 6. Configure Scheduling (Optional)

Options → Schedule:

- Enable Scheduling: **Yes**
- Active Hours: **02:00 - 06:00**
- Days: All days

With GPU transcoding CPU impact is minimal. Scheduling mainly limits I/O during peak viewing hours.

## Monitoring and Optimization

### Check Progress

Web UI Dashboard shows queue, current transcode progress, time remaining, space savings.

### Prometheus Queries

**Tdarr Container Memory** (in Grafana):

```promql
container_memory_usage_bytes{name=~"tdarr.*"} / container_spec_memory_limit_bytes{name=~"tdarr.*"} * 100
```

### Increase Concurrent Transcodes

After 48 hours monitoring, if resources allow:

1. Check pod memory usage: `kubectl top pod -n gpu`
2. Verify no Jellyfin playback issues
3. Increase concurrent transcodes to 2 in Options → Transcode Options
4. Monitor 24 more hours

## Best Practices

- **Start Small**: Test with a single TV series first
- **Verify Results**: Check video quality before processing entire library
- **Backup Important Media**: Before enabling "Replace Original"
- **Skip Already Optimized**: Use "Check Video Codec" plugin
- **Preserve Audio Quality**: Use `copy` for audio tracks
- **Check Logs Weekly**: Look for failed transcodes

## Performance Tuning

If transcodes too slow: change preset from `medium` to `fast`, or reduce CRF 23 → 21.

If quality too low: change preset from `medium` to `slow`, reduce CRF 23 → 21.

## Troubleshooting

For detailed troubleshooting, see [docs/troubleshooting/tdarr.md](../troubleshooting/tdarr.md)

**Quick Checks**:

1. **Pod not running**:

   ```bash
   kubectl get pods -n gpu
   kubectl describe pod -n gpu <pod-name>
   ```

2. **Check logs**:

   ```bash
   kubectl logs -n gpu deployment/tdarr -f
   ```

3. **Restart**:

   ```bash
   kubectl rollout restart deployment/tdarr -n gpu
   ```

4. **GPU not available**:

   ```bash
   kubectl exec -it -n gpu deployment/tdarr -- nvidia-smi
   ```

## Backup Considerations

**What to backup** (in PVC `configs` and `server-data`):

- `/app/configs` — flow/plugin configuration
- `/app/server` — transcode history and queue state

**Do not backup**:

- `/temp` — RAM disk, cleared after jobs

## Security

- Web UI has no built-in authentication
- Protected via Traefik `admin-ipallowlist` middleware (192.168.30.0/24 + Tailscale 100.64.0.0/10)

## References

- [Tdarr Official Documentation](https://docs.tdarr.io/)
- [Troubleshooting Guide](../troubleshooting/tdarr.md)
- [Flow Configuration](tdarr-flow-configuration.md)
- [NVENC Patch](https://github.com/keylase/nvidia-patch)
