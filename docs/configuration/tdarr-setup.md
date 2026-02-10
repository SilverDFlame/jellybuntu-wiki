# Tdarr Setup and Configuration Guide

## Deployment Status

**Status**: ✅ **Successfully Deployed and Tested** (November 3, 2025)

**Initial Test Results**:

- **13 successful transcodes** completed overnight (first production run)
- **Average compression ratio**: 40-50% file size reduction (H.264 → H.265)
- **Sample results**:
  - 556.9 MB → 321.7 MB (42% reduction, ratio: 57.78)
  - 556.5 MB → 264.8 MB (52% reduction, ratio: 47.58)
  - 555.9 MB → 355.6 MB (36% reduction, ratio: 63.96)
  - 556.4 MB → 366.5 MB (34% reduction, ratio: 65.87)

**System Impact**:

- Jellyfin VM memory usage: Stable within limits
- Proxmox host: No impact (as expected)
- Jellyfin playback: Unaffected during transcoding
- Container resources: Within allocated limits (1GB server + 8GB node)

**Lessons Learned**:

- Fixed permissions issue with `chown -R 1000:1000 /opt/jellyfin/tdarr`
- "Input File" node is critical for flow to work (see troubleshooting docs)
- Memory limits increased to 8GB for node to handle 4K HDR transcoding (OOM kills with 2-4GB)
- Added SYS_NICE capability for x265 NUMA memory optimization
- Mount media as read-only for server to prevent chown attempts on NFS share

---

## Overview

Tdarr is an automated media transcoding and optimization system that processes your media library to:

- Standardize video codecs (e.g., convert to H.265 for better compression)
- Reduce storage requirements (typically 30-50% space savings)
- Optimize streaming performance (reduce transcoding load on Jellyfin)
- Ensure consistent media quality across your library

**Deployment Location**: Jellyfin VM (VMID 400, 192.168.0.12)

**Resource Allocation**:

- Tdarr Server: 1GB RAM (coordination, web UI, database)
- Tdarr Node: 8GB RAM (transcoding worker - required for 4K HDR)
- Total: 9GB limit, but actual usage ~3-4GB (Jellyfin VM has 10GB)
- SYS_NICE capability enabled for x265 NUMA memory optimization

## Architecture

Tdarr uses a server-node architecture:

1. **Tdarr Server** (Port 8265)
   - Web UI for configuration and monitoring
   - Manages transcode queue and library scanning
   - Stores transcode history and statistics
   - Coordinates work distribution to nodes

2. **Tdarr Node** (Port 8267)
   - Performs actual transcoding work
   - Communicates with server via port 8266
   - Can run concurrently with other nodes (future scaling)

## Access

- **Local Network**: http://192.168.0.12:8265
- **Tailscale**: http://jellyfin.discus-moth.ts.net:8265
- **Homarr Dashboard**: Add to Media Server section at http://media-services.discus-moth.ts.net:7575

## Initial Configuration

### 1. Access Web UI

After deployment via [`playbooks/services/tdarr.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/tdarr.yml), access the web UI at:

```text
http://jellyfin.discus-moth.ts.net:8265
```

### 2. Configure Libraries

Navigate to **Libraries** tab and click on a library to configure:

**TV Shows Library** (Source tab):

- Source: `/media/tv`
- **Toggles to ENABLE** (blue):
  - Folder Watch: **ON** (monitors for new files)
  - Process Library: **ON**
  - Transcodes: **ON**
  - Health Checks: **ON**
  - Scan on Start: **ON** (scans library when Tdarr starts)
- **Toggles to DISABLE** (gray):
  - Closed Caption Check: OFF
  - Directory Library: OFF
- **Scanner settings**:
  - Run an hourly Scan (Find new): **ON**
  - File scanner threads: 1
  - Hold files after scanning: OFF
- **Folder watch settings**:
  - Folder watch scan interval: **30** seconds
  - Folder watch: Use file system events: **OFF** (polling required for NFS)

**Movies Library** (Source tab):

- Source: `/media/movies`
- Same toggle and scanner settings as TV Shows

**Important for NFS**: Keep "Use file system events" OFF since inotify doesn't work over NFS mounts. The 30-second
polling interval handles this.

### 3. Configure Transcode Settings

Navigate to **Options** > **Transcode Options**:

**General Settings**:

- Concurrent Transcodes: **1** (start conservatively)
- Priority: **Low** (nice value to avoid impacting Jellyfin)
- Health Check Interval: 60 seconds
- Worker Timeout: 6 hours

**File Handling**:

- Replace Original: **Yes** (after successful transcode)
- Keep Original: **No** (to save space)
- Clean Transcode Cache: **Yes** (after completion)

**Cache Path** (for RAM disk):

- Set cache/temp path to: `/temp`
- This uses the RAM disk for zero-SSD-wear transcoding

> **Important**: Use `/temp` (the container path), not `/mnt/transcode-cache/tdarr` (the host path). The container
> cannot see host paths directly.

### RAM Disk Configuration

The Tdarr containers mount a RAM disk from the Proxmox host for transcode cache operations. This prevents SSD wear from
the constant read/write cycles during transcoding.

**Path Mapping**:

| Context | Path | Description |
|---------|------|-------------|
| Proxmox Host | `/mnt/transcode-cache` | 32GB tmpfs RAM disk |
| Jellyfin VM | `/mnt/transcode-cache` | virtio-fs mount from host |
| Tdarr Container | `/temp` | Bind mount to VM's RAM disk |

**In Tdarr UI**: Always use `/temp` when configuring cache paths. This is the path as seen from inside the container.

**Verification**:

```bash
# Check RAM disk is mounted in VM
ssh ansible@jellyfin.discus-moth.ts.net "df -h /mnt/transcode-cache"

# Verify container mount
ssh ansible@jellyfin.discus-moth.ts.net "podman inspect tdarr-node --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}\n{{end}}' | grep temp"
```

### 4. Create Transcode Profiles

Tdarr uses "flows" (plugins) to define transcode operations.

**⚠️ IMPORTANT**: For the complete, production-tested flow configuration, see the detailed guide:
[docs/configuration/tdarr-flow-configuration.md](tdarr-flow-configuration.md)

**4-Branch Architecture**: The flow handles all content types with proper HDR/SDR detection:

| Branch | 10-Bit | HDR Params | CRF |
|--------|--------|------------|-----|
| 4K HDR | Yes | Yes | 23 |
| 4K SDR | No | No | 23 |
| 1080p HDR | Yes | Yes | 21 |
| 1080p SDR | No | No | 21 |

**Critical Requirements**:

- **Input File node** must be the first node in any flow (common failure point!)
- **Check HDR Video** must BRANCH (not just detect) to route HDR/SDR content correctly
- Follow the connection map exactly for branching flows
- Test with single files before enabling on full libraries

#### Recommended Starting Profile: H.265 Standardization

Navigate to **Libraries** > Select Library > **Transcode**:

**Plugin Stack**:

1. **Check File**: Skip if already H.265
   - Plugin: `Check Video Codec`
   - Codec: `hevc`
   - Action: Skip if match

2. **Transcode to H.265**:
   - Plugin: `Transcode Video`
   - Output Codec: `hevc` (H.265)
   - CRF Quality: `23` (balanced quality/size)
   - Preset: `medium` (balanced speed/compression)
   - Audio: `copy` (no transcode, faster)
   - Container: `mkv` (preserves metadata)

3. **Remove Subtitle Tracks** (optional):
   - Plugin: `Remove Subtitle Tracks`
   - Action: Remove all (reduces file size)
   - Note: Only enable if you don't use subtitles

#### Advanced Profile: 4K Optimization

For 4K content that needs aggressive compression:

**Plugin Stack**:

1. **Check Resolution**: Only process 4K
   - Plugin: `Check Video Resolution`
   - Resolution: `>=2160p`
   - Action: Skip if not match

2. **Transcode 4K to H.265**:
   - Codec: `hevc`
   - CRF: `28` (higher compression for 4K)
   - Preset: `slow` (better compression)
   - Downscale: `No` (keep 4K resolution)

### 5. Configure Node Workers (GPU + CPU)

Navigate to **Nodes** > **JellyfinNode** to configure worker settings:

**GPU Worker Settings** (with NVENC):

| Setting | Recommended Value | Rationale |
|---------|-------------------|-----------|
| **GPU Workers** | **2** | GTX 1080 NVENC limit (unpatched driver) |
| **CPU Workers** | **0** | GPU handles encoding; CPU unnecessary |
| **Health Check CPU** | **1** | Health checks don't use GPU |

**Why These Values:**

- **GPU Workers = 2**: The GTX 1080 can decode unlimited streams but only encode 2 simultaneous streams (NVIDIA consumer
  lock). This is a hardware/driver limitation, not a performance limitation.
- **CPU Workers = 0**: With GPU transcoding, CPU encoding is unnecessary and wasteful. Set to 1 only if you have jobs
  that explicitly require CPU encoding (rare).
- **Health Checks**: These analyze files without transcoding and should use CPU.

#### Optional: Unlock NVENC Stream Limit

NVIDIA consumer cards (GTX series) have an artificial 2-stream encode limit. To remove this limit:

```bash
# On Jellyfin VM - applies the NVENC patch
ssh ansible@jellyfin.discus-moth.ts.net "sudo bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch.sh)\""
```

After patching, you can increase GPU workers to 3-4 (limited by VRAM/bandwidth, not artificial lock).

**Performance with GPU (GTX 1080 NVENC):**

| Content Type | CPU-Only | GPU (NVENC) |
|--------------|----------|-------------|
| 4K HEVC → H.265 | ~0.3x realtime | **3-5x realtime** |
| 4K H.264 → H.265 | ~0.5x realtime | **5-8x realtime** |
| 1080p → H.265 | ~2x realtime | **15-20x realtime** |

**Example**: A 2-hour 4K movie that took 5-8 hours with CPU now takes **15-40 minutes** with NVENC.

### 6. Configure Scheduling (Optional)

To limit transcoding to off-peak hours:

Navigate to **Options** > **Schedule**:

**Schedule Settings**:

- Enable Scheduling: **Yes**
- Active Hours: **02:00 - 06:00** (2 AM to 6 AM)
- Days: All days
- Action: Pause queue outside active hours

**Alternative**: With GPU transcoding, the CPU impact is minimal. Scheduling may be unnecessary unless you want to
limit I/O during peak viewing hours.

## Resource Management

### Memory Limits

Memory limits are enforced at the Docker level:

- Tdarr Server: 1GB limit, 512MB reservation
- Tdarr Node: **8GB limit, 4GB reservation** (required for 4K HDR transcoding)

The 8GB node limit is necessary because:

- 4K H.265 transcoding uses ~1.7GB RSS per job
- x265 encoder needs memory for lookahead frames and buffers
- 25GB+ 4K HDR files require significant headroom
- Lower limits (2-4GB) cause OOM kills

Check current usage:

```bash
ssh ansible@jellyfin.discus-moth.ts.net "podman stats --no-stream tdarr-server tdarr-node"
```

Verify memory limit:

```bash
ssh ansible@jellyfin.discus-moth.ts.net "podman inspect tdarr-node --format '{{.HostConfig.Memory}}'"
# Should show: 8589934592 (8GB in bytes)
```

### CPU Priority and Capabilities

Tdarr node has SYS_NICE capability enabled for x265 NUMA memory optimization:

```bash
ssh ansible@jellyfin.discus-moth.ts.net "podman inspect tdarr-node --format '{{.HostConfig.CapAdd}}'"
# Should show: [CAP_SYS_NICE]
```

This allows x265 to use `set_mempolicy()` for optimal memory allocation during 4K transcoding.

### Concurrent Transcodes

Start with **1 concurrent transcode**:

- Monitor CPU and memory usage for 48 hours
- Check if Jellyfin playback is affected
- Gradually increase to 2 if resources allow

To adjust:

1. Access Web UI > **Options** > **Transcode Options**
2. Change "Concurrent Transcodes" value
3. Save and restart queue

## Monitoring and Optimization

### Check Transcode Progress

Web UI Dashboard shows:

- Files in queue
- Current transcode progress
- Estimated time remaining
- Space savings achieved

### Monitor Resource Usage

**Jellyfin VM Memory**:

```bash
ssh ansible@jellyfin.discus-moth.ts.net "free -h"
```

Expected usage with Tdarr active:

- Jellyfin: ~1-3GB
- Tdarr Server: ~512MB - 1GB
- Tdarr Node: ~2-4GB (during 4K transcode)
- Total: ~4-8GB / 10GB (40-80%)

Note: Jellyfin VM was increased to 10GB to accommodate 4K HDR transcoding requirements.

**Container Stats**:

```bash
ssh ansible@jellyfin.discus-moth.ts.net "podman stats --no-stream"
```

**Proxmox Host** (should be unchanged):

```bash
ssh root@jellybuntu.discus-moth.ts.net "free -h"
```

### Prometheus Queries

Monitor via Grafana dashboard:

**Jellyfin VM Memory Usage**:

```promql
(1 - (node_memory_MemAvailable_bytes{instance="jellyfin"} / node_memory_MemTotal_bytes{instance="jellyfin"})) * 100
```

**Tdarr Container Memory**:

```promql
container_memory_usage_bytes{name=~"tdarr.*"} / container_spec_memory_limit_bytes{name=~"tdarr.*"} * 100
```

## Performance Tuning

### Increase Concurrent Transcodes

After monitoring for 48 hours, if resources allow:

1. Check Jellyfin VM memory usage < 60%
2. Verify no Jellyfin playback issues
3. Increase concurrent transcodes to 2
4. Monitor for another 24 hours

### Optimize Transcode Speed

If transcodes are too slow:

- Change preset from `medium` to `fast` (less compression)
- Reduce CRF from 23 to 21 (faster, slightly larger files)
- Disable audio transcoding (use `copy`)

If quality is too low:

- Change preset from `medium` to `slow` (better compression)
- Reduce CRF from 23 to 21 (higher quality, larger files)

### Storage Optimization

Track space savings:

1. Web UI > **Statistics** tab
2. View "Space Saved" metric
3. Expected: 30-50% reduction for H.264 → H.265

## Best Practices

### Library Organization

- **Start Small**: Test with a single TV series first
- **Verify Results**: Check video quality before processing entire library
- **Backup Important Media**: Before enabling "Replace Original"

### Transcode Strategy

- **Skip Already Optimized**: Use "Check Video Codec" plugin
- **Preserve Audio Quality**: Use `copy` for audio tracks
- **Batch Processing**: Let queue run during off-peak hours
- **Monitor First Week**: Check for quality issues or errors

### Maintenance

- **Check Logs Weekly**: Look for failed transcodes
- **Clean Temp Directory**: Ensure `/temp` is cleared after jobs
- **Review Statistics**: Track space savings and processing time
- **Update Profiles**: Adjust CRF/preset based on results

## Troubleshooting

For detailed troubleshooting, see [docs/troubleshooting/tdarr.md](../troubleshooting/tdarr.md)

**Quick Checks**:

1. **Containers Not Running**:

   ```bash
   ssh ansible@jellyfin.discus-moth.ts.net "podman ps | grep tdarr"
   ```

2. **Check Logs**:

   ```bash
   ssh ansible@jellyfin.discus-moth.ts.net "podman logs tdarr-server"
   ssh ansible@jellyfin.discus-moth.ts.net "podman logs tdarr-node"
   ```

3. **Restart Services** (via systemd):

   ```bash
   ssh ansible@jellyfin.discus-moth.ts.net "systemctl --user restart tdarr-server tdarr-node"
   ```

## File Locations

All Tdarr data on Jellyfin VM:

- **Configuration**: `/opt/jellyfin/tdarr/configs`
- **Server Data**: `/opt/jellyfin/tdarr/server`
- **Logs**: `/opt/jellyfin/tdarr/logs`
- **Transcode Cache**: `/temp` (container path) → `/mnt/transcode-cache/tdarr` (host RAM disk)
- **Media (NFS Mount)**: `/mnt/data/media`
- **Quadlet Files**: `~/.config/containers/systemd/tdarr-*.container`

## Backup Considerations

**What to Backup**:

- Configuration: `/opt/jellyfin/tdarr/configs`
- Server database: `/opt/jellyfin/tdarr/server`

**What NOT to Backup**:

- Logs: `/opt/jellyfin/tdarr/logs` (regenerated)
- Temp cache: `/mnt/transcode-cache/tdarr` (RAM disk, cleared after jobs)

**Backup Command**:

```bash
ssh ansible@jellyfin.discus-moth.ts.net "tar -czf /tmp/tdarr-backup-$(date +%Y%m%d).tar.gz -C /opt/jellyfin/tdarr configs server"
```

## Security Considerations

- **No Authentication**: Tdarr Web UI has no built-in authentication
- **Network Access**: Only accessible via local network + Tailscale
- **Firewall**: UFW restricts access to trusted networks
- **File Permissions**: Runs as NFS user (PUID/PGID set in compose)

**Recommendation**: Access Tdarr only via Tailscale VPN for additional security.

## Next Steps

After initial configuration:

1. **Test with Small Library**: Process 1-2 TV episodes
2. **Verify Quality**: Watch transcoded content on Jellyfin
3. **Monitor Resources**: Check memory/CPU for 48 hours
4. **Scale Up**: Gradually increase concurrent transcodes
5. **Full Library**: Process entire media collection

## References

- **Tdarr Official Documentation**: https://docs.tdarr.io/
- **Troubleshooting Guide**: `docs/troubleshooting/tdarr.md`
- **Feasibility Analysis**: `docs/troubleshooting/tdarr-feasibility-analysis.md`
- **GPU Passthrough**: `docs/configuration/gpu-passthrough.md`
- **Playbook**: [`playbooks/services/tdarr.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/tdarr.yml)
- **NVENC Patch**: https://github.com/keylase/nvidia-patch
