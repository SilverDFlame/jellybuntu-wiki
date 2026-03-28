# Jellyseerr

> Media request management — lets users browse and request movies and TV shows

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace on `k8s-media` |
| **Access** | `https://jellyseerr.elysium.industries` |
| **Port** | 5055 |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/jellyseerr.yaml` |

## Key Config

- Config stored in a 1 Gi PVC at `/app/config` — includes DB, session data, and settings
- Memory: 256 Mi request / 512 Mi limit
- No PostgreSQL backend; Jellyseerr uses its own SQLite database inside the config PVC

## Common Operations

```bash
# Restart
kubectl rollout restart deployment/jellyseerr -n media

# Logs
kubectl logs -f deployment/jellyseerr -n media

# Shell
kubectl exec -it deployment/jellyseerr -n media -- /bin/sh
```
