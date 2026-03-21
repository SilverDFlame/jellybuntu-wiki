# Tdarr

> Distributed media transcoding — optimises library encoding and reduces file sizes

| Field | Value |
|-------|-------|
| **Runs on** | k3s `gpu` namespace on `k8s-gpu` |
| **Access** | `https://tdarr.elysium.industries` |
| **Port** | 8265 (web UI), 8266 (server API) |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/gpu/tdarr.yaml` |

## Key Config

- Runs as a single container (`ghcr.io/haveagitgat/tdarr`) with `internalNode: "true"` — avoids
  the startup race condition that occurs when server and node are separate containers
- NVIDIA GPU time-slice: requests and limits both `nvidia.com/gpu: "1"`, scheduled on `k8s-gpu`
- Memory: 4 Gi request / 8 Gi limit for GPU transcoding workloads
- NFS media library mounted at `/data` via `nfs-media-gpu` PVC (shared with Jellyfin)
- Transcode temp files use host path `/mnt/transcode-cache/tdarr` at `/temp`

## Common Operations

```bash
# Restart
kubectl rollout restart deployment/tdarr -n gpu

# Logs
kubectl logs -f deployment/tdarr -n gpu

# Shell
kubectl exec -it deployment/tdarr -n gpu -- /bin/sh
```
