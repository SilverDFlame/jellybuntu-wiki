# unrar-cronjob

> CronJob that extracts stuck multipart RAR archives the *arr apps can't import, then
> triggers a rescan

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace on `k8s-media` |
| **Access** | No web UI — CronJob, every 5 minutes |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/unrar-cronjob.yaml` |
| **Image** | `unrar-sweep` (custom, built + cosign-signed by `jellybuntu/.woodpecker/build-unrar-sweep.yml`) |

Replaces the former **Unpackerr** deployment. Unpackerr no-ops on RAR v3/v5 multipart
archives; this Go orchestrator with a baked static `unrar` handles them.

## Key Config

- Schedule `*/5 * * * *`, `concurrencyPolicy: Forbid`, `backoffLimit: 0`.
- Extracts to the NFS media library (`nfs-media` PVC at `/data`), chowns extracted media to
  uid 3000 (needs `runAsUser: 0`), then triggers the routed *arr rescan.
- Config from the `unrar-sweep-config` ConfigMap at `/config/config.yaml`; secrets from
  `media-secrets`.
- Digest-pinned via Flux ImagePolicy. Memory 128 Mi request / 1 Gi limit.

## Common Operations

```bash
# Inspect the CronJob + recent runs
kubectl get cronjob unrar-cronjob -n media
kubectl get jobs -n media -l app.kubernetes.io/name=unrar-cronjob

# Logs from the most recent run
kubectl logs -n media job/$(kubectl get jobs -n media -l app.kubernetes.io/name=unrar-cronjob \
  --sort-by=.metadata.creationTimestamp -o name | tail -1 | cut -d/ -f2)

# Trigger a manual run
kubectl create job -n media --from=cronjob/unrar-cronjob unrar-manual-$(date +%s)
```

## Gotchas

- When a torrent client move changes the completed-download path (e.g. qBittorrent→Deluge
  moving Sonarr's completed dir), the ConfigMap `SCAN_PATHS` must be updated or RARs park in
  `importPending`.
