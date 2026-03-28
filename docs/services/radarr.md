# Radarr

> Movie collection manager — monitors RSS feeds and sends grabs to download clients

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace on `k8s-media` |
| **Access** | `https://radarr.elysium.industries` |
| **Port** | 7878 |
| **Database** | PostgreSQL `radarr_main` and `radarr_log` on `db` VM |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/radarr.yaml` |

## Key Config

- PostgreSQL backend: init container writes `config.xml` with DB credentials on first boot,
  then patches the API key on subsequent starts
- DB host is `192.168.30.16` (the `db` VM on the media VLAN)
- NFS media library mounted at `/data` via `nfs-media` PVC
- Memory: 512 Mi request / 1 Gi limit

## Common Operations

```bash
# Restart
kubectl rollout restart deployment/radarr -n media

# Logs
kubectl logs -f deployment/radarr -n media

# Shell
kubectl exec -it deployment/radarr -n media -- /bin/sh
```
