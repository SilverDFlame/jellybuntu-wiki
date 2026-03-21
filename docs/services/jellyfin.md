# Jellyfin

> Media server for streaming movies, TV, and music to all devices on the network

| Field | Value |
|-------|-------|
| **Runs on** | k3s `gpu` namespace on `k8s-gpu` |
| **Access** | `https://jellyfin.elysium.industries` |
| **Port** | 8096 |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/gpu/jellyfin.yaml` |

## Key Config

- NVIDIA GPU time-slice: requests and limits both set to `nvidia.com/gpu: "1"` — pod is
  scheduled only on `k8s-gpu` via node selector and GPU toleration
- Memory: 2 Gi request / 6 Gi limit to accommodate heavy transcoding sessions
- NFS media library mounted read-write at `/data` via `nfs-media-gpu` PVC
- Transcode cache uses a host path (`/mnt/transcode-cache/jellyfin`) mounted at
  `/config/data/transcodes` — bypasses NFS for low-latency temp writes
- Config volume is a 5 Gi NFS-backed PVC at `/config`

## Common Operations

```bash
# Restart
kubectl rollout restart deployment/jellyfin -n gpu

# Logs
kubectl logs -f deployment/jellyfin -n gpu

# Shell
kubectl exec -it deployment/jellyfin -n gpu -- /bin/sh
```
