# jellyhunt

> Missing + cutoff-unmet hunt tool — searches Sonarr/Radarr for gaps each run, throttled by
> a Postgres-backed per-item backoff

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace on `k8s-media` (CronJob, every 2 h) |
| **Access** | No web UI |
| **Database** | PostgreSQL `jellyhunt` on the `db` VM (`192.168.30.16`, sslmode `require`) |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/jellyhunt.yaml` |
| **Image** | `jellyhunt` (custom, built + cosign-signed via `jellybuntu/.woodpecker`) |

In-house Huntarr replacement. One search cycle per CronJob run.

## Key Config

- Schedule `0 */2 * * *`, `concurrencyPolicy: Forbid`, `backoffLimit: 0`.
- Each run searches Sonarr + Radarr for missing and cutoff-unmet items, rotated + throttled
  via per-item backoff state stored in the `jellyhunt` Postgres DB.
- `SONARR_URL` / `RADARR_URL` are non-secret cluster DNS; API keys + `MEDIA_POSTGRES_PASSWORD`
  come from `media-secrets`.
- Digest-pinned via Flux ImagePolicy. Tiny footprint: 32 Mi request / 128 Mi limit.

## Common Operations

```bash
# Inspect CronJob + recent runs
kubectl get cronjob jellyhunt -n media

# Logs from the latest run
kubectl logs -n media job/$(kubectl get jobs -n media -l app.kubernetes.io/name=jellyhunt \
  --sort-by=.metadata.creationTimestamp -o name | tail -1 | cut -d/ -f2)

# Manual run
kubectl create job -n media --from=cronjob/jellyhunt jellyhunt-manual-$(date +%s)
```
