# Matrix/Synapse Communication Server

Matrix is a decentralized communication protocol providing encrypted text, voice, and video chat.
This guide covers the Synapse homeserver deployment on the Elysium VM, including Element Call
via LiveKit for real-time voice/video.

> **IMPORTANT**: All Matrix services run as **rootless Podman containers with Quadlet** on the
> elysium VM (192.168.40.21). Use `systemctl --user` commands.

## Overview

- **VM**: elysium (VMID 202, 192.168.40.21)
- **VLAN**: Games (40)
- **Deployment**: Rootless Podman with Quadlet via `podman_app` role (pod-based)
- **Phase**: 3 service
- **Playbook**: [`playbooks/services/matrix.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/matrix.yml)
- **Bootstrap**: [`playbooks/utility/matrix-bootstrap.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/utility/matrix-bootstrap.yml)
- **Server Name**: `elysium.discus-moth.ts.net`

## Architecture

Elysium runs 6 containers organized in a pod-based architecture. Five services share a Podman pod
(`matrix-pod`) with a shared network namespace. coturn runs on the host network because it needs
real client IPs for NAT traversal.

```text
┌─────────────────────────────────────────────────────────┐
│  elysium VM (192.168.40.21)                             │
│                                                         │
│  ┌─────────────── matrix-pod ────────────────────────┐  │
│  │  (shared network namespace on matrix-net)         │  │
│  │                                                   │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────────┐    │  │
│  │  │ Synapse  │  │ Postgres │  │  LiveKit SFU  │   │  │
│  │  │  :8008   │  │  :5432   │  │  :7880/:7881  │   │  │
│  │  └──────────┘  └──────────┘  └──────────────┘    │  │
│  │                                                   │  │
│  │  ┌──────────────┐  ┌───────────────────┐         │  │
│  │  │ lk-jwt-svc   │  │  Synapse Admin    │         │  │
│  │  │  :8880       │  │  :8080            │         │  │
│  │  └──────────────┘  └───────────────────┘         │  │
│  └───────────────────────────────────────────────────┘  │
│                                                         │
│  ┌──────────────────────┐                               │
│  │  coturn (host net)   │                               │
│  │  :3478               │                               │
│  └──────────────────────┘                               │
└─────────────────────────────────────────────────────────┘
```

## VM Specifications

| Resource | Value |
|----------|-------|
| CPU Cores | 4 (shared) |
| CPU Units | 1024 |
| Memory | 8GB (8192MB) |
| Disk | 64GB (local-zfs) |
| Startup Order | 6 |

## Components

### Synapse (Homeserver)

The core Matrix homeserver handling all client API and room operations.

| Setting | Value |
|---------|-------|
| Image | `ghcr.io/element-hq/synapse:v1.147.1` |
| Port | 8008 (Client API) |
| Memory | 4GB (2GB reservation) |
| Config | [`services/configs/matrix/homeserver.yaml.j2`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/configs/matrix/homeserver.yaml.j2) |

Key configuration:

- **Server name**: `elysium.discus-moth.ts.net`
- **Registration**: Disabled (use registration tokens via Synapse Admin)
- **Federation**: Disabled (internal use only, whitelist is empty)
- **Media uploads**: 50MB max, URL previews enabled
- **Remote media retention**: 90 days
- **Well-known discovery**: Served by Synapse (`serve_client_wellknown: true`)
- **MatrixRTC features**: MSC3266 (Room Summary), MSC4222 (state_after), MSC4140 (delayed events)
- **Rate limiting**: Relaxed for private server (0.5/s with burst 30 for messages)

An iptables PREROUTING rule redirects port 80 to 8008 on the VM so Element Desktop can discover
the well-known response at `http://elysium.discus-moth.ts.net/.well-known/matrix/client`.

### PostgreSQL 16

Database backend for Synapse.

| Setting | Value |
|---------|-------|
| Image | `docker.io/postgres:16.12-alpine` |
| Port | 5432 (pod-internal) |
| Memory | 1GB (512MB reservation) |
| Database | `synapse` |
| User | `synapse` |
| Encoding | UTF-8 with C collation |
| Restart Policy | `always` (auto-recovers even after manual stop) |

Credentials are stored in the SOPS-encrypted vault:

```yaml
# In group_vars/all.sops.yaml
vault_matrix_postgres_password: "..."
```

### LiveKit (WebRTC SFU)

Selective Forwarding Unit for Element Call voice/video.

| Setting | Value |
|---------|-------|
| Image | `docker.io/livekit/livekit-server:v1.9.9` |
| HTTP API Port | 7880 |
| WebRTC TCP Port | 7881 |
| Media UDP Range | 50000-50060 |
| Memory | 1GB (512MB reservation) |
| Max Participants | 20 per room |
| Config | [`services/configs/matrix/livekit.yaml.j2`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/configs/matrix/livekit.yaml.j2) |

LiveKit uses the VM's VLAN IP (`192.168.40.21`) for ICE candidates. Rooms are auto-created
when the first participant joins.

### lk-jwt-service (MatrixRTC Authorization)

Bridges Matrix authentication with LiveKit by validating Matrix access tokens and issuing
LiveKit JWTs.

| Setting | Value |
|---------|-------|
| Image | `ghcr.io/element-hq/lk-jwt-service:0.4.1` |
| Port | 8880 (mapped from container 8080) |
| Memory | 256MB (128MB reservation) |
| LiveKit URL | `ws://localhost:7880` (pod-internal) |

The service validates tokens against Synapse's OpenID endpoint at
`http://localhost:8008/_matrix/federation/v1/openid/userinfo` (pod-internal).

> **Note**: The federation listener resource is kept active in Synapse specifically so
> lk-jwt-service can call the OpenID userinfo endpoint, even though federation is disabled.

### coturn (TURN/STUN Server)

Provides NAT traversal for WebRTC connections when clients can't establish direct peer-to-peer links.

| Setting | Value |
|---------|-------|
| Image | `docker.io/coturn/coturn:4.8.0-r1` |
| TURN Port | 3478 (TCP + UDP) |
| Relay Range | 49152-49200 (UDP) |
| Memory | 512MB (256MB reservation) |
| Network | Host (not in pod) |
| Config | [`services/configs/matrix/turnserver.conf.j2`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/configs/matrix/turnserver.conf.j2) |

Key configuration:

- **Authentication**: Static auth secret shared with Synapse (`vault_matrix_coturn_auth_secret`)
- **Relay IP**: `192.168.40.21` (VLAN IP)
- **Security**: Blocks relay to all private IP ranges except the Matrix VM's own IP
- **No TLS**: Internal network only; Tailscale encrypts transit
- **Host network mode**: Required to see real client IPs for NAT traversal

> **Tailscale requirement**: Subnet routing for `192.168.40.0/24` must be advertised so remote
> clients can reach coturn relay candidates on `192.168.40.21`.

### Synapse Admin (Web UI)

Web-based administration interface for managing users, rooms, and registration tokens.

| Setting | Value |
|---------|-------|
| Image | `docker.io/awesometechnologies/synapse-admin:0.11.1` |
| Port | 8080 (mapped from container 80) |
| Memory | 256MB (128MB reservation) |

Access via Traefik proxy or directly at `http://elysium.discus-moth.ts.net:8080`.

## Deployment

### Initial Deployment

```bash
./bin/runtime/ansible-run.sh playbooks/services/matrix.yml
```

The playbook:

1. Installs `iptables-persistent` and adds port 80 to 8008 redirect
2. Deploys configuration templates (homeserver.yaml, livekit.yaml, turnserver.conf, synapse-log.config)
3. Creates the Podman pod and all 6 containers via `podman_app` role
4. Verifies all 6 containers are running
5. Waits for Synapse API to respond on `/_matrix/client/versions`

### Bootstrap (One-Time)

After initial deployment, run the bootstrap playbook to generate the signing key and create
the admin user:

```bash
./bin/runtime/ansible-run.sh playbooks/utility/matrix-bootstrap.yml
```

The bootstrap playbook:

1. Generates the Synapse signing key (server's cryptographic identity)
2. Restarts Synapse to load the new key
3. Creates the `admin` user with password from vault (`vault_services_admin_password`)
4. Uses a temporary password file (not CLI args) to avoid `/proc` exposure

> **Warning**: The signing key is the server's cryptographic identity. Never delete a
> non-empty signing key file. The playbook only removes 0-byte keys left by interrupted startups.

## Firewall Rules

Ports managed by UFW on the elysium VM:

| Port | Protocol | Purpose |
|------|----------|---------|
| 443 | TCP | Matrix federation HTTPS |
| 7880 | TCP | LiveKit HTTP API |
| 7881 | TCP | LiveKit WebRTC TCP |
| 3478 | TCP + UDP | TURN/STUN |
| 49152:49200 | UDP | coturn relay range |
| 50000:50060 | UDP | LiveKit media range |

Cross-VLAN rules (restricted to reverse proxy VM only):

| Port | Protocol | Source | Purpose |
|------|----------|--------|---------|
| 80 | TCP | Proxy VM | Well-known discovery |
| 8008 | TCP | Proxy VM | Synapse Client API |
| 8080 | TCP | Proxy VM | Synapse Admin UI |
| 8880 | TCP | Proxy VM | LiveKit JWT Service |

## Service Management

```bash
# SSH to elysium VM
ssh -i ~/.ssh/ansible_homelab ansible@elysium.discus-moth.ts.net

# Check all container statuses
systemctl --user status postgres synapse livekit lk-jwt-service coturn synapse-admin

# Restart the entire pod (all pod containers restart together)
systemctl --user restart matrix-pod-pod

# Restart individual services
systemctl --user restart synapse
systemctl --user restart postgres
systemctl --user restart livekit
systemctl --user restart coturn

# View logs for a specific service
journalctl --user -u synapse -f
journalctl --user -u postgres -f
journalctl --user -u livekit -f
journalctl --user -u coturn -f

# List running containers
podman ps

# Check Synapse health
curl -s http://localhost:8008/_matrix/client/versions | python3 -m json.tool
```

## Client Connection

### Element X (Recommended)

1. Install Element X from your app store
2. Tap **Sign in**
3. Set homeserver to: `http://elysium.discus-moth.ts.net:8008`
4. Enter your username and password

### Element Web/Desktop

1. Download Element from [element.io](https://element.io/download)
2. Click **Sign in**
3. Change homeserver to: `http://elysium.discus-moth.ts.net:8008`
4. Enter credentials

### Synapse Admin

1. Navigate to `http://elysium.discus-moth.ts.net:8080`
2. Login with the `admin` user
3. Password is stored as `vault_services_admin_password` in the SOPS vault

## Post-Setup

After bootstrap, recommended next steps:

1. Login to Synapse Admin and generate registration tokens for new users
2. Create a Space (e.g., "Elysium") and rooms:
   - `#general` (text)
   - `#gaming` (text)
   - `#voice-lobby` (voice/video via Element Call)
3. Verify Tailscale subnet routing for `192.168.40.0/24`
4. Test Element Call voice/video in the `#voice-lobby` room

## Data Directories

| Path | Purpose |
|------|---------|
| `/opt/matrix/` | Base directory |
| `/opt/matrix/synapse/data/` | Synapse data (media, signing key) — owned by UID 991 |
| `/opt/matrix/synapse/config/` | Synapse configuration |
| `/opt/matrix/postgres/data/` | PostgreSQL database |
| `/opt/matrix/livekit/config/` | LiveKit configuration |
| `/opt/matrix/coturn/config/` | coturn configuration |

## See Also

- [Architecture Overview](../architecture.md) - Infrastructure design
- [Service Endpoints](service-endpoints.md) - All service URLs and ports
- [Matrix Troubleshooting](../troubleshooting/matrix.md) - Issue resolution
- [Mumble Setup](mumble-setup.md) - Legacy voice chat (retained during migration)
- [Resource Allocation](resource-allocation.md) - VM resource planning
