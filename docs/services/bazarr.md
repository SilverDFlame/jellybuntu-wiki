# Bazarr

> Subtitle management — automatically downloads subtitles for movies and TV shows

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace on `k8s-media` |
| **Access** | `https://bazarr.elysium.industries` |
| **Port** | 6767 |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/bazarr.yaml` |

## Key Config

- PostgreSQL credentials injected via `custom-cont-init.d/postgres-config.sh` init script;
  credential source is `media-secrets`
- NFS media library mounted at `/data` via `nfs-media` PVC (same mount as Sonarr/Radarr so
  Bazarr can write subtitle files alongside media)
- Memory: 256 Mi request / 512 Mi limit

## Common Operations

```bash
# Restart
kubectl rollout restart deployment/bazarr -n media

# Logs
kubectl logs -f deployment/bazarr -n media

# Shell
kubectl exec -it deployment/bazarr -n media -- /bin/sh
```
