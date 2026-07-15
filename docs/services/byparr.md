# Byparr

> FlareSolverr-compatible proxy that solves Cloudflare challenges for Prowlarr indexers

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace on `k8s-media` |
| **Access** | `https://byparr.elysium.industries` |
| **Port** | 8191 |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/byparr.yaml` |

Prowlarr points its FlareSolverr proxy setting at Byparr so Cloudflare-protected indexers
resolve.

## Key Config

- Image `ghcr.io/thephaseless/byparr`, semver major-pinned to v2 (Flux ImagePolicy).
- Runs non-root, `allowPrivilegeEscalation: false`, all capabilities dropped.
- Config PVC: 1 Gi `nfs-client` at `/config`.
- Memory 768 Mi request / 1536 Mi limit (headless browser is memory-hungry).

## Common Operations

```bash
# Restart
kubectl rollout restart deployment/byparr -n media

# Logs
kubectl logs -f deployment/byparr -n media

# Smoke-test the solver endpoint from inside the namespace
kubectl run -n media --rm -it curl --image=curlimages/curl --restart=Never -- \
  -s -X POST http://byparr.media.svc.cluster.local:8191/v1 \
  -H 'Content-Type: application/json' \
  -d '{"cmd":"request.get","url":"https://example.com"}'
```
