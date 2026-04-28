# Jellyfin Configuration

Jellyfin is an open-source media server that organizes and streams your media collection.

> **Deployment**: HelmRelease `jellyfin` in the `gpu` namespace, pinned to k8s-gpu node (192.168.30.41).
> Managed via Flux GitOps — edit `clusters/jellybuntu/gpu/jellyfin.yaml` in `jellybuntu-helm`.

## Overview

| Field | Value |
|-------|-------|
| Namespace | `gpu` |
| Node | k8s-gpu (192.168.30.41) |
| Image | `lscr.io/linuxserver/jellyfin:latest` |
| Port | 8096 |
| URL | https://jellyfin.elysium.industries (public, no IP restriction) |
| GPU | GTX 1080, time-sliced (1 virtual GPU shared with Tdarr via NVIDIA device plugin) |

## Storage

| Volume | Type | Host Path / Claim | Container Path |
|--------|------|-------------------|----------------|
| config | PVC 5 Gi (nfs-client) | — | `/config` |
| media | PVC `nfs-media-gpu` (1 Ti) | — | `/data` |
| transcode-cache | hostPath | `/mnt/transcode-cache/jellyfin` on k8s-gpu | `/config/data/transcodes` |

Media libraries reference paths under `/data` (e.g., `/data/media/movies`, `/data/media/tv`).

## Environment

| Variable | Value |
|----------|-------|
| PUID | 1000 |
| PGID | 1000 |
| TZ | America/Los_Angeles |
| JELLYFIN_PublishedServerUrl | jellyfin.elysium.industries |

## Resources

| | Memory | GPU |
|-|--------|-----|
| Requests | 2 Gi | 1 |
| Limits | 6 Gi | 1 |

Node selector: `jellybuntu.io/role: gpu`

## Operations

```bash
# Logs
kubectl logs -n gpu deployment/jellyfin -f

# Restart
kubectl rollout restart deployment/jellyfin -n gpu

# Shell into container
kubectl exec -it -n gpu deployment/jellyfin -- /bin/bash

# Verify GPU access from inside container
kubectl exec -it -n gpu deployment/jellyfin -- nvidia-smi

# Force Flux reconcile
flux reconcile helmrelease jellyfin -n gpu
```

## Config Changes

1. Edit `clusters/jellybuntu/gpu/jellyfin.yaml` in `jellybuntu-helm`
2. Open PR → merge to `main`
3. Flux reconciles automatically (or force with `flux reconcile helmrelease jellyfin -n gpu`)

## Hardware Transcoding

Jellyfin has access to 1 virtual GPU (time-sliced GTX 1080, shared with Tdarr).

### Configure NVENC in Dashboard

1. Dashboard → Playback → Transcoding
2. Hardware acceleration: **NVIDIA NVENC**
3. Enable hardware decoding for: H264, HEVC, MPEG2, VC1, VP8/VP9
4. Enable **hardware encoding**
5. Enable **tone mapping** for HDR content

### Verify GPU

```bash
kubectl exec -it -n gpu deployment/jellyfin -- nvidia-smi
```

### Transcode Cache

The transcode cache is a hostPath mount to `/mnt/transcode-cache/jellyfin` on k8s-gpu — a RAM disk
(tmpfs) on the node. In the Jellyfin UI this appears as `/config/data/transcodes`. No configuration
needed; it is set automatically via the HelmRelease.

### NVENC Stream Limit

GTX 1080 consumer cards have an artificial 2-stream NVENC encode limit. To remove:

```bash
# Run on k8s-gpu node
ssh -i ~/.ssh/ansible_homelab ansible@192.168.30.41 \
  "sudo bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch.sh)\""
```

After patching, increase concurrent transcodes to 3-4 in Dashboard → Playback → Transcoding.

## Initial Setup

1. Navigate to https://jellyfin.elysium.industries
2. Select language
3. Create admin account
4. Add media libraries:
   - Movies: `/data/media/movies`
   - TV Shows: `/data/media/tv`
   - Music: `/data/media/music` (optional)
5. Complete setup wizard

## Library Configuration

### Movies Library

1. Dashboard → Libraries → Add Media Library
2. Content type: **Movies** | Display name: **Movies**
3. Folder: `/data/media/movies`
4. Metadata: Language English, Country US, enable TheMovieDb

### TV Shows Library

1. Dashboard → Libraries → Add Media Library
2. Content type: **Shows** | Display name: **TV Shows**
3. Folder: `/data/media/tv`
4. Metadata: enable TheMovieDb and TheTVDB

### Automatic Library Refresh

Dashboard → Libraries → (library) → Edit → Enable **real time monitoring**

Or trigger via API:

```bash
# From inside cluster — use in-cluster service DNS
curl -X POST "http://jellyfin.gpu.svc.cluster.local:8096/Library/Refresh" \
  -H "X-Emby-Token: YOUR_API_KEY"
```

## User Management

### Creating Users

Dashboard → Users → Add User. Configure username, password, library access, playback permissions.

### User Permissions

| Permission | Recommended For |
|------------|-----------------|
| Administrator | Admin only |
| Allow media playback | All users |
| Allow media deletion | Admin only |
| Allow remote connections | All users (behind Traefik) |
| Allow transcoding | All users (with limits) |

### Jellyseerr Integration

Jellyseerr connects to Jellyfin for user sync and library state. In Jellyseerr Settings → Jellyfin:

- Hostname: `http://jellyfin.gpu.svc.cluster.local:8096` (in-cluster)
- API Key: generate in Jellyfin Dashboard → API Keys

## Playback Settings

Dashboard → Playback → Streaming:

| Setting | Recommended Value |
|---------|------------------|
| Maximum streaming bitrate | 120 Mbps (local) |
| Internet streaming bitrate | 20 Mbps |
| Direct play | Preferred |
| Allow subtitle extraction | Enabled |

Subtitles (Dashboard → Playback → Subtitles):

- Preferred language: English
- Mode: Default
- Prefer forced subtitles: Yes
- Burn in: Only when necessary

## Plugin Management

Dashboard → Plugins → Catalog. Recommended plugins:

| Plugin | Purpose |
|--------|---------|
| Open Subtitles | Automatic subtitle downloads |
| Playback Reporting | Track viewing statistics |
| Trakt | Sync watch history |
| TMDb Box Sets | Automatic collection creation |
| AniDB | Anime metadata |
| Intro Skipper | Skip intros automatically |

Restart Jellyfin pod to activate after install:

```bash
kubectl rollout restart deployment/jellyfin -n gpu
```

## API

```bash
# Base URL (public)
https://jellyfin.elysium.industries

# In-cluster
http://jellyfin.gpu.svc.cluster.local:8096

# Get system info
curl "https://jellyfin.elysium.industries/System/Info" -H "X-Emby-Token: API_KEY"

# Trigger library scan
curl -X POST "https://jellyfin.elysium.industries/Library/Refresh" -H "X-Emby-Token: API_KEY"

# Get active sessions
curl "https://jellyfin.elysium.industries/Sessions" -H "X-Emby-Token: API_KEY"
```

## Integration with Arr Stack

Sonarr/Radarr manage downloads and organize to NFS storage. Jellyfin scans `/data` and picks up new content.
No direct connection between Arr apps and Jellyfin is required, but Sonarr/Radarr can send webhooks
to trigger library scans via the API endpoint above.

## Concurrent Transcodes

Dashboard → Playback → Transcoding → Concurrent transcodes:

- Start at 2 (NVENC limit on unpatched driver)
- After NVENC patch: increase to 3-4
- Monitor GPU utilization via `nvidia-smi` in the pod

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Pod not running | `kubectl get pods -n gpu` → `kubectl describe pod -n gpu <pod>` |
| GPU not available | `kubectl exec -n gpu deployment/jellyfin -- nvidia-smi` |
| Transcoding failing | Check logs: `kubectl logs -n gpu deployment/jellyfin -f` |
| Library not updating | Trigger manual scan via API or check NFS PVC mount |
| Can't access UI | Verify Traefik IngressRoute: `kubectl get ingressroute -n gpu` |

## See Also

- [Jellyfin Troubleshooting](../troubleshooting/jellyfin.md)
- [Tdarr Configuration](tdarr-setup.md) - Automatic transcoding
- [Jellyseerr Setup](jellyseerr-setup.md) - Media requests
- [Service Endpoints](service-endpoints.md)
