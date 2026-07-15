# autobrr

> IRC announce-channel racer — matches release announcements against filters and pushes
> grabs to the *arr apps in real time

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace on `k8s-media` |
| **Access** | `https://autobrr.elysium.industries` |
| **Port** | 7474 |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/autobrr.yaml` |

Adds IRC racing to the media stack — announcements hit filters far faster than RSS polling.

## Key Config

- Image `ghcr.io/autobrr/autobrr` (semver, Flux ImagePolicy).
- Listens on `0.0.0.0:7474`; `AUTOBRR__CHECK_FOR_UPDATES: "false"` (Flux owns upgrades).
- `AUTOBRR__SESSION_SECRET` from `media-secrets`.
- Config PVC: 5 Gi `nfs-client` at `/config`.
- Memory 64 Mi request / 256 Mi limit.

## Common Operations

```bash
# Restart
kubectl rollout restart deployment/autobrr -n media

# Logs (watch IRC connect + filter matches)
kubectl logs -f deployment/autobrr -n media
```

## Gotchas

- Phase 1 is live (IRC racing). A seed-only farm + orchestrator extension is deferred; the
  orchestrator retention won't clean torrents pushed directly by the farm.
- The nzbgeek cart-RSS `&amp;` entity trap surfaces items as `Unknown-Series` — watch for it
  in filter matches.
