# SABnzbd

> Usenet download client with Newshosting and Giganews provider support

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace on `k8s-media` |
| **Access** | `https://sabnzbd.elysium.industries` |
| **Port** | 8080 |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/sabnzbd.yaml` |

## Key Config

- Usenet provider credentials (Newshosting and Giganews) are injected from `media-secrets`
  at startup via init scripts (`patch-config.sh`, `configure-api.sh`)
- API key is also sourced from `media-secrets` so Sonarr/Radarr/Lidarr can connect
  without storing it in config files
- NFS media library mounted at `/data` via `nfs-media` PVC; completed downloads land
  under `/data/usenet/`
- Memory: 1 Gi request / 2 Gi limit (Usenet can be CPU/memory intensive during par2 repair)

## Common Operations

```bash
# Restart
kubectl rollout restart deployment/sabnzbd -n media

# Logs
kubectl logs -f deployment/sabnzbd -n media

# Shell
kubectl exec -it deployment/sabnzbd -n media -- /bin/sh
```
