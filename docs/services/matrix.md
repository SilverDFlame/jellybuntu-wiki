# Matrix

> Self-hosted Matrix homeserver (Synapse) with an admin UI and LiveKit voice/video via lk-jwt

| Field | Value |
|-------|-------|
| **Runs on** | k3s `matrix` namespace on `k8s-ops` |
| **Access** | `https://chat.elysium.industries` (Synapse) |
| **Port** | 8008 (Synapse), 8080 (synapse-admin and lk-jwt) |
| **Database** | PostgreSQL `synapse` on `db` VM |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/ops/matrix/` |

## Components

| Container | Image | Access URL |
|-----------|-------|------------|
| `synapse` | `ghcr.io/element-hq/synapse` | `https://chat.elysium.industries` |
| `synapse-admin` | `docker.io/awesometechnologies/synapse-admin` | `https://synapse-admin.elysium.industries` |
| `lk-jwt` | `ghcr.io/element-hq/lk-jwt-service` | `https://lk-jwt.elysium.industries` |
| `livekit` | (livekit server) | `wss://livekit.elysium.industries` |

## Key Config

- Synapse config is templated: an init container runs `envsubst` on `homeserver.yaml` from
  a ConfigMap and writes the result to an emptyDir — secrets come from `matrix-secrets`
- Signing key is injected as a read-only secret mount at
  `/data/chat.elysium.industries.signing.key`
- lk-jwt connects to LiveKit at `wss://livekit.elysium.industries` and is restricted to
  homeserver `chat.elysium.industries`
- Memory: Synapse 2 Gi request / 4 Gi limit

## Common Operations

```bash
# Restart Synapse
kubectl rollout restart deployment/synapse -n matrix

# Restart synapse-admin
kubectl rollout restart deployment/synapse-admin -n matrix

# Logs
kubectl logs -f deployment/synapse -n matrix
kubectl logs -f deployment/lk-jwt -n matrix

# Shell into Synapse
kubectl exec -it deployment/synapse -n matrix -- /bin/sh
```
