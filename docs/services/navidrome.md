# Navidrome

> Music streaming server with a Subsonic-compatible API

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace on `k8s-media` |
| **Access** | `https://navidrome.elysium.industries` |
| **Port** | 4533 |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/navidrome.yaml` |

## Key Config

- Music library mounted read-only at `/music` with sub-path `media/music` from the
  `nfs-media` PVC — Navidrome cannot write to the library
- Library scan schedule: every `1h` (`ND_SCANSCHEDULE`)
- Transcoding config exposed via `ND_ENABLETRANSCODINGCONFIG: "true"`
- Session timeout: 24 hours
- Runs as non-root with all capabilities dropped

## Common Operations

```bash
# Restart
kubectl rollout restart deployment/navidrome -n media

# Logs
kubectl logs -f deployment/navidrome -n media

# Shell
kubectl exec -it deployment/navidrome -n media -- /bin/sh
```
