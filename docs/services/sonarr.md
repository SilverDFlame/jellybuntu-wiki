# Sonarr

> TV show collection manager — monitors RSS feeds and sends grabs to download clients

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace on `k8s-media` |
| **Access** | `https://sonarr.elysium.industries` |
| **Port** | 8989 |
| **Database** | PostgreSQL `sonarr_main` and `sonarr_log` on `db` VM |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/sonarr.yaml` |

## Key Config

- PostgreSQL backend: an init container writes `config.xml` with DB credentials on first boot,
  then patches the API key on subsequent starts
- DB host is `192.168.30.16` (the `db` VM on the media VLAN)
- NFS media library mounted at `/data` via `nfs-media` PVC; download paths live under `/data`
- Memory: 512 Mi request / 1 Gi limit

## Common Operations

```bash
# Restart
kubectl rollout restart deployment/sonarr -n media

# Logs
kubectl logs -f deployment/sonarr -n media

# Shell
kubectl exec -it deployment/sonarr -n media -- /bin/sh
```
