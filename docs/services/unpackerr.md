# Unpackerr

> Background archive extractor — watches Sonarr, Radarr, and Lidarr for completed downloads
> and extracts compressed archives so the *arr apps can import them

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace on `k8s-media` |
| **Access** | No web UI — runs headless |
| **Port** | N/A |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/unpackerr.yaml` |

## Key Config

- Connects to Sonarr, Radarr, and Lidarr via their in-cluster service URLs using API keys
  from `media-secrets`
- Watches both torrent and usenet paths for each *arr app:
  - Sonarr: `/data/torrents/tv-sonarr`, `/data/usenet/tv`
  - Radarr: `/data/torrents/radarr`, `/data/usenet/movies`
  - Lidarr: `/data/torrents/music`, `/data/usenet/music`
- Extract interval: every `2m`; start delay: `1m`; retry delay: `5m`; max retries: 3
- Original archives are not deleted after extraction (`UN_*_DELETE_ORIG: "false"`)
- Runs non-root with all capabilities dropped; memory 256 Mi request / 512 Mi limit

## Common Operations

```bash
# Restart
kubectl rollout restart deployment/unpackerr -n media

# Logs
kubectl logs -f deployment/unpackerr -n media
```
