# Recyclarr

> Declarative sync of TRaSH-Guides quality profiles + custom formats into Sonarr and Radarr

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace on `k8s-media` (CronJob, daily 04:00) |
| **Access** | No web UI |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/recyclarr.yaml` (config in `recyclarr-configmap.yaml`) |

Idempotent: each run pulls the TRaSH-Guides templates and syncs quality profiles + custom
formats declaratively, so the *arr scoring config is GitOps-managed rather than hand-tuned.

## Key Config

- Image `docker.io/recyclarr/recyclarr`, semver major-pinned to **v8** (v9 gated for a
  deliberate upgrade). Flux ImagePolicy.
- Schedule `0 4 * * *`, `backoffLimit: 1` (a transient flap waits for tomorrow's run instead
  of spawning 7 error pods), `concurrencyPolicy: Forbid`.
- An init container fixes git `safe.directory` for the TRaSH repo clone.
- v8 needs `RECYCLARR_CONFIG_DIR: /config` set explicitly (v7's implicit `APP_DATA` default
  was removed). Secrets from `media-secrets`.
- Config PVC: 256 Mi `nfs-client` at `/config`.

## Common Operations

```bash
# Inspect CronJob + last run
kubectl get cronjob recyclarr -n media

# Manual sync run
kubectl create job -n media --from=cronjob/recyclarr recyclarr-manual-$(date +%s)
kubectl logs -n media -f job/recyclarr-manual-<ts>
```

## Notes

- Inline comments in the config **must** match the canonical TRaSH custom-format name — that
  enables drift-checking against a TRaSH-Guides clone. Sonarr and Radarr use different repack
  ID namespaces; don't cross-reference them.
