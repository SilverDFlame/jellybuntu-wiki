# Prowlarr

> Indexer aggregator — manages torrent and Usenet indexers for Sonarr, Radarr, and Lidarr

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace on `k8s-media` |
| **Access** | `https://prowlarr.elysium.industries` |
| **Port** | 9696 |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/prowlarr.yaml` |

## Key Config

- A custom init script (`custom-cont-init.d/postgres-config.sh`) configures the PostgreSQL
  connection at container start — credentials come from `media-secrets`
- Memory: 256 Mi request / 512 Mi limit
- Config PVC is 1 Gi (indexer data is small)

## Common Operations

```bash
# Restart
kubectl rollout restart deployment/prowlarr -n media

# Logs
kubectl logs -f deployment/prowlarr -n media

# Shell
kubectl exec -it deployment/prowlarr -n media -- /bin/sh
```
