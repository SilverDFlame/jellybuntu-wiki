# Matrix/Synapse Communication Server

Matrix is a decentralized communication protocol providing encrypted text, voice, and video chat.
This guide covers the Synapse homeserver and associated services deployed on k3s.

> **Deployment**: All Matrix services run in the `matrix` namespace on k8s-ops node (192.168.30.44).
> Managed via Flux GitOps — edit files under `clusters/jellybuntu/ops/matrix/` in `jellybuntu-helm`.

## Overview

All services: `matrix` namespace, k8s-ops node, node selector `jellybuntu.io/role: ops`.

| Service | Image | URL | IP Restricted |
|---------|-------|-----|---------------|
| synapse | `ghcr.io/element-hq/synapse:v1.147.1` | https://chat.elysium.industries | No (public) |
| livekit | `docker.io/livekit/livekit-server:v1.9.9` | https://livekit.elysium.industries | No |
| lk-jwt | `ghcr.io/element-hq/lk-jwt-service:0.4.1` | https://lk-jwt.elysium.industries | No |
| coturn | `docker.io/coturn/coturn:4.8.0-r1` | hostNetwork (TURN/STUN :3478) | — |
| synapse-admin | `docker.io/awesometechnologies/synapse-admin:0.11.1` | https://synapse-admin.elysium.industries | Yes |

**Server name**: `chat.elysium.industries`

**Database**: External PostgreSQL at 192.168.30.16:5432, database `synapse`, user `synapse`.

## Secrets

All sensitive values live in `matrix-secrets` (SOPS-encrypted Secret):

| Key | Purpose |
|-----|---------|
| `SYNAPSE_SHARED_SECRET` | Shared secret for Synapse registration API |
| `REGISTRATION_SHARED_SECRET` | Registration token generation secret |
| `POSTGRES_PASSWORD` | PostgreSQL password for `synapse` user |
| `LIVEKIT_API_KEY` | LiveKit server API key |
| `LIVEKIT_API_SECRET` | LiveKit server API secret |
| `COTURN_AUTH_SECRET` | Static auth secret shared between coturn and Synapse |
| `FORM_SECRET` | Synapse form secret |

Edit secrets:

```bash
sops ~/coding/mirrors/jellybuntu-helm/clusters/jellybuntu/ops/matrix/secrets.yaml
```

Signing key is in a separate Secret `synapse-signing-key` (SOPS-encrypted).

> **Warning**: The signing key is the server's cryptographic identity. Never delete a non-empty signing key.

## Config Templating

`homeserver.yaml` is stored as a ConfigMap (`synapse-config`). An `envsubst` init container runs
at pod startup, substitutes secrets from `matrix-secrets` into the template, and writes the result
to `/config/homeserver.yaml` before Synapse starts. Same pattern for `livekit.yaml` and `coturn`'s
`turnserver.conf`.

## Service Details

### Synapse (Homeserver)

- Port: 8008
- Resources: requests 2 Gi, limits 4 Gi
- Storage: 10 Gi PVC (nfs-client) → `/data`
- Config: ConfigMap `synapse-config` → envsubst init → `/config/homeserver.yaml`
- Signing key: Secret `synapse-signing-key` mounted at `/data/chat.elysium.industries.signing.key`

Key configuration:

- **Server name**: `chat.elysium.industries`
- **Registration**: Disabled (use registration tokens via Synapse Admin)
- **Federation**: Disabled (internal use only, whitelist is empty)
- **Media uploads**: 50MB max, URL previews enabled
- **Remote media retention**: 90 days
- **Well-known discovery**: `serve_client_wellknown: true`
- **MatrixRTC features**: MSC3266 (Room Summary), MSC4222 (state_after), MSC4140 (delayed events)
- **Rate limiting**: Relaxed for private server (0.5/s with burst 30 for messages)

> The federation listener is kept active in Synapse (even though federation is disabled) so
> `lk-jwt-service` can call the OpenID userinfo endpoint at `/_matrix/federation/v1/openid/userinfo`.

### LiveKit (WebRTC SFU)

Selective Forwarding Unit for Element Call voice/video.

- HTTP API: port 7880 (also exposed via IngressRoute `livekit.elysium.industries`)
- WebRTC TCP: port 7881 (hostPort on k8s-ops)
- Media UDP: ports 50000-50020 (hostPorts on k8s-ops)
- Config: ConfigMap `livekit-config` → envsubst init → `/config/livekit.yaml`
- Max participants: 20 per room

### lk-jwt-service (MatrixRTC Authorization)

Bridges Matrix authentication with LiveKit — validates Matrix access tokens, issues LiveKit JWTs.

- Port: 8080
- `LIVEKIT_URL`: `wss://livekit.elysium.industries`
- `LIVEKIT_FULL_ACCESS_HOMESERVERS`: `chat.elysium.industries`
- Key/Secret injected from `matrix-secrets`

### coturn (TURN/STUN)

Provides NAT traversal for WebRTC when direct peer-to-peer is unavailable.

- TURN port: 3478 (TCP + UDP)
- **hostNetwork: true** — required so coturn sees real client IPs for NAT traversal
- Config: ConfigMap `coturn-config` → envsubst init → `/config/turnserver.conf`
- Auth secret shared with Synapse via `COTURN_AUTH_SECRET`
- No TLS (internal network; Tailscale encrypts transit)

### Synapse Admin

Web UI for managing users, rooms, and registration tokens.

- Port: 8080
- IP restricted via Traefik `admin-ipallowlist` (192.168.30.0/24 + 100.64.0.0/10)

## Operations

```bash
# Logs
kubectl logs -n matrix deployment/synapse -f
kubectl logs -n matrix deployment/livekit -f
kubectl logs -n matrix deployment/coturn -f

# Restart
kubectl rollout restart deployment/synapse -n matrix
kubectl rollout restart deployment/livekit -n matrix

# Pod status
kubectl get pods -n matrix

# Force Flux reconcile
flux reconcile kustomization matrix -n flux-system --with-source

# Edit secrets (SOPS)
sops ~/coding/mirrors/jellybuntu-helm/clusters/jellybuntu/ops/matrix/secrets.yaml

# Check Synapse health
kubectl exec -n matrix deployment/synapse -- \
  curl -s http://localhost:8008/_matrix/client/versions | python3 -m json.tool
```

## Config Changes

1. Edit files under `clusters/jellybuntu/ops/matrix/` in `jellybuntu-helm`
2. Open PR → merge to `main`
3. Flux reconciles automatically, or force:
   ```bash
   flux reconcile kustomization matrix -n flux-system --with-source
   ```

## Client Connection

### Element X (Recommended)

1. Install Element X
2. Tap **Sign in**
3. Homeserver: `https://chat.elysium.industries`
4. Enter credentials

### Element Web/Desktop

1. Download Element from [element.io](https://element.io/download)
2. Click **Sign in** → change homeserver to `https://chat.elysium.industries`
3. Enter credentials

### Synapse Admin UI

Navigate to https://synapse-admin.elysium.industries (requires Tailscale or 192.168.30.0/24 access).

Login with the `admin` user. Password from `vault_services_admin_password` in SOPS vault.

## Post-Setup

1. Login to Synapse Admin → generate registration tokens for new users
2. Create a Space and rooms (general, gaming, voice-lobby)
3. Test Element Call voice/video in a voice room

## Synapse Configuration Reference

Key settings in `homeserver.yaml` (via ConfigMap `synapse-config`):

### Registration

```yaml
enable_registration: false
registration_requires_token: true
```

Tokens managed via Synapse Admin UI.

### Federation

```yaml
federation_domain_whitelist: []
```

Empty whitelist = no federation. Federation listener kept active for lk-jwt OpenID endpoint only.

### Rate Limiting (relaxed for private server)

```yaml
rc_message:
  per_second: 0.5
  burst_count: 30
```

### MatrixRTC / Element Call

MSC3266, MSC4222, MSC4140 enabled in `experimental_features`. Element Call requires:

1. LiveKit server running and reachable at `wss://livekit.elysium.industries`
2. lk-jwt-service running at `https://lk-jwt.elysium.industries`
3. `well_known_config` in homeserver.yaml pointing Element clients to the LiveKit/JWT URLs

## Firewall / Network Notes

coturn uses `hostNetwork: true` on k8s-ops — ports 3478 (TCP+UDP) must be open to clients.
LiveKit uses `hostPort` bindings for 7881/TCP and 50000-50020/UDP on k8s-ops.

Ensure k8s-ops node firewall (or network policy) allows these ports from client subnets.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Pod not running | `kubectl describe pod -n matrix <pod>` |
| Synapse won't start | Check init container logs: `kubectl logs -n matrix <pod> -c envsubst` |
| Element Call fails | Verify livekit and lk-jwt pods running; check LIVEKIT_URL in lk-jwt env |
| TURN not working | coturn is hostNetwork — verify port 3478 reachable on k8s-ops IP (192.168.30.44) |
| Login fails | Verify POSTGRES_PASSWORD in `matrix-secrets` matches DB user password |

## See Also

- [Architecture Overview](../architecture.md)
- [Service Endpoints](service-endpoints.md)
- [Matrix Troubleshooting](../troubleshooting/matrix.md)
