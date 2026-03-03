# Traefik v3 Reverse Proxy Setup

Centralized TLS-terminating reverse proxy for all Jellybuntu services, running as a rootless Podman
Quadlet container on a dedicated VM.

---

## Overview

| Property | Value |
|----------|-------|
| **VM Name** | `reverse-proxy` |
| **VMID** | 900 |
| **VLAN** | Management (VLAN 10) |
| **IP Address** | 192.168.10.20 |
| **Runtime** | Rootless Podman (Quadlet systemd integration) |
| **Proxy Engine** | Traefik v3 with file provider |
| **TLS** | Tailscale certificates (`*.discus-moth.ts.net`) |
| **Config Management** | Ansible role [`roles/traefik_proxy/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/traefik_proxy) |

Traefik terminates TLS for all internal services and routes traffic based on hostname (SNI/Host header).
DNS rewrites in AdGuard redirect service hostnames to the proxy VM, where Traefik forwards requests
to the appropriate backend over plain HTTP on the LAN.

---

## Architecture

### Traffic Flow

```text
Client (Tailscale)
    │
    │  DNS query: sonarr.discus-moth.ts.net
    ▼
AdGuard Home (192.168.10.11)
    │  DNS rewrite → 192.168.10.20 (proxy VM)
    ▼
Traefik (192.168.10.20:443)
    │  TLS termination (Tailscale cert)
    │  Host header match → route to backend
    ▼
Backend Service (LAN IP:port)
    e.g., media-services (192.168.30.13:8989) for Sonarr
```

### Key Design Decisions

- **File provider, not Docker provider** — Traefik reads routes from YAML config files, not from
  container labels. No Podman socket is mounted into the container.
- **Direct LAN IPs for backends** — Backend services are addressed by their VLAN IP, not their
  Tailscale hostname. This avoids a DNS loop: AdGuard rewrites `sonarr.discus-moth.ts.net` to the
  proxy IP, so using the same hostname as the backend URL would route back to Traefik.
- **Hot-reloadable dynamic config** — The file provider watches the dynamic config directory. Route
  and middleware changes take effect without restarting the container.
- **Rootless Podman** — The container runs under the `ansible` user with `NET_BIND_SERVICE` for
  ports 80/443. A sysctl (`net.ipv4.ip_unprivileged_port_start=80`) allows host-side binding.

---

## VM Specifications

| Resource | Value |
|----------|-------|
| **Cores** | 1 |
| **CPU Units** | 512 |
| **RAM** | 512 MB |
| **Disk** | 32 GB |
| **CPU Type** | host |
| **VLAN** | Management (10) |
| **IP** | 192.168.10.20 |
| **Startup Order** | 5 |

Defined in [`infrastructure/terraform/vms.tf`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/vms.tf)
(module `reverse_proxy`).

---

## Deployment

Traefik is a **Phase 3** service — deployed after backend VMs are running and Tailscale is
authenticated on the proxy VM.

**Playbook:**
[`playbooks/services/traefik-proxy.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/traefik-proxy.yml)

**Role:**
[`roles/traefik_proxy/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/traefik_proxy)

**Role dependencies** (from
[`meta/main.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/traefik_proxy/meta/main.yml)):

- `common` — base system setup, Podman environment facts
- `tailscale` — Tailscale installation and authentication

**Deploy command:**

```bash
./bin/runtime/ansible-run.sh playbooks/services/traefik-proxy.yml
```

### Prerequisites

1. Proxy VM provisioned (Phase 1 OpenTofu)
2. Tailscale installed and authenticated on the proxy VM (Phase 2)
3. Backend VMs running their services (Phase 3)
4. AdGuard DNS overrides configured (see [AdGuard Home](adguard-home.md))

---

## Static Configuration

The static config defines entrypoints, logging, and the file provider. It is templated from
[`templates/traefik.yaml.j2`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/traefik_proxy/templates/traefik.yaml.j2)
and deployed to `/opt/traefik/config/traefik.yaml`.

**Changes to static config require a container restart.**

### Entrypoints

| Name | Port | Behavior |
|------|------|----------|
| `web` | :80 | Permanent HTTP → HTTPS redirect |
| `websecure` | :443 | TLS termination for all proxied services |

### File Provider

```yaml
providers:
  file:
    directory: /etc/traefik/dynamic
    watch: true
```

Traefik watches the dynamic config directory and hot-reloads route changes automatically.

### Logging

| Log Type | Path | Format |
|----------|------|--------|
| Application log | `/var/log/traefik/traefik.log` | JSON |
| Access log | `/var/log/traefik/access.log` | JSON |

Log level defaults to `INFO`. Logs are rotated weekly (4 rotations, compressed) via logrotate.

### Other Settings

- **Dashboard**: Disabled by default (`traefik_api_dashboard: false`)
- **Version check**: Disabled (`checkNewVersion: false`)
- **Anonymous usage**: Disabled (`sendAnonymousUsage: false`)

---

## Dynamic Configuration

The dynamic config defines TLS settings, middlewares, routers, and service backends. Templated from
[`templates/traefik_dynamic.yaml.j2`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/traefik_proxy/templates/traefik_dynamic.yaml.j2)
and deployed to `/opt/traefik/config/dynamic/services.yaml`.

**Changes to dynamic config are hot-reloaded — no restart needed.**

### TLS Configuration

**TLS options (minimum TLS 1.2, strict SNI):**

```yaml
tls:
  options:
    default:
      minVersion: VersionTLS12
      sniStrict: true
      cipherSuites:
        - TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384
        - TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256
        - TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256
        - TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256
```

**Default certificate store**: The proxy VM's own Tailscale cert (`proxy.discus-moth.ts.net`) is
used as the fallback. Per-domain certificates are loaded for each proxied service hostname.

### Middlewares

Two middleware profiles are defined:

**`secure-headers`** — Strict security headers for most services:

- HSTS (1 year, includeSubdomains, preload)
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `X-Frame-Options: DENY`
- `Content-Security-Policy: default-src 'self'; frame-ancestors 'none'`

**`secure-headers-media`** — Relaxed headers for media services (Jellyfin, Tdarr, Navidrome):

- Same HSTS and nosniff settings
- Relaxed CSP: allows `'unsafe-inline'`, `'unsafe-eval'`, `blob:`, `data:` (required for media
  playback and JS frameworks)
- `frame-ancestors 'self'` instead of `DENY` (allows embedding within same origin)

### Routers

All routers use the `websecure` entrypoint with TLS enabled. Routing is by `Host()` header match,
with path-based routing for Matrix endpoints:

| Router | Rule | Service | Middleware |
|--------|------|---------|------------|
| `matrix-well-known` | `Host(elysium...) && PathPrefix(/.well-known/matrix)` | `elysium-synapse-wellknown` | `secure-headers` |
| `matrix-api` | `Host(elysium...) && PathPrefix(/_matrix)` | `elysium-synapse-api` | `secure-headers` |
| `synapse-admin` | `Host(synapse-admin...)` | `elysium-synapse-admin` | `secure-headers` |
| `lk-jwt-service` | `Host(lk-jwt...)` | `elysium-lk-jwt` | `secure-headers` |
| `sonarr` | `Host(sonarr...)` | `sonarr-svc` | `secure-headers` |
| `radarr` | `Host(radarr...)` | `radarr-svc` | `secure-headers` |
| `prowlarr` | `Host(prowlarr...)` | `prowlarr-svc` | `secure-headers` |
| `jellyseerr` | `Host(jellyseerr...)` | `jellyseerr-svc` | `secure-headers` |
| `bazarr` | `Host(bazarr...)` | `bazarr-svc` | `secure-headers` |
| `lidarr` | `Host(lidarr...)` | `lidarr-svc` | `secure-headers` |
| `navidrome` | `Host(navidrome...)` | `navidrome-svc` | `secure-headers-media` |
| `byparr` | `Host(byparr...)` | `byparr-svc` | `secure-headers` |
| `jellyfin` | `Host(jellyfin...)` | `jellyfin-svc` | `secure-headers-media` |
| `tdarr` | `Host(tdarr...)` | `tdarr-svc` | `secure-headers-media` |
| `qbittorrent` | `Host(qbittorrent...)` | `qbittorrent-svc` | `secure-headers` |
| `sabnzbd` | `Host(sabnzbd...)` | `sabnzbd-svc` | `secure-headers` |

> Matrix routers use priority values (`matrix-well-known: 20`, `matrix-api: 10`) to ensure
> `/.well-known/matrix` paths match before the broader `/_matrix` prefix.

### Services

All services are HTTP load balancers pointing to backend LAN IPs. Each includes a health check
(30s interval, 5s timeout) with `passHostHeader: true`.

---

## Proxied Services

| Service | Domain | Backend VM | Backend Port | Health Check |
|---------|--------|------------|--------------|--------------|
| Sonarr | `sonarr.discus-moth.ts.net` | media-services (192.168.30.13) | 8989 | `/ping` |
| Radarr | `radarr.discus-moth.ts.net` | media-services (192.168.30.13) | 7878 | `/ping` |
| Prowlarr | `prowlarr.discus-moth.ts.net` | media-services (192.168.30.13) | 9696 | `/ping` |
| Jellyseerr | `jellyseerr.discus-moth.ts.net` | media-services (192.168.30.13) | 5055 | `/` |
| Bazarr | `bazarr.discus-moth.ts.net` | media-services (192.168.30.13) | 6767 | `/` |
| Lidarr | `lidarr.discus-moth.ts.net` | media-services (192.168.30.13) | 8686 | `/ping` |
| Navidrome | `navidrome.discus-moth.ts.net` | media-services (192.168.30.13) | 4533 | `/` |
| Byparr | `byparr.discus-moth.ts.net` | media-services (192.168.30.13) | 8191 | `/` |
| Jellyfin | `jellyfin.discus-moth.ts.net` | jellyfin (192.168.30.12) | 8096 | `/health` |
| Tdarr | `tdarr.discus-moth.ts.net` | jellyfin (192.168.30.12) | 8265 | `/` |
| qBittorrent | `qbittorrent.discus-moth.ts.net` | download-clients (192.168.30.14) | 8080 | `/` |
| SABnzbd | `sabnzbd.discus-moth.ts.net` | download-clients (192.168.30.14) | 8085 | `/` |
| Matrix API | `elysium.discus-moth.ts.net/_matrix/` | elysium (192.168.40.21) | 8008 | `/_matrix/client/versions` |
| Matrix well-known | `elysium.discus-moth.ts.net/.well-known/matrix` | elysium (192.168.40.21) | 80 | `/.well-known/matrix/client` |
| Synapse Admin | `synapse-admin.discus-moth.ts.net` | elysium (192.168.40.21) | 8080 | `/` |
| LiveKit JWT | `lk-jwt.discus-moth.ts.net` | elysium (192.168.40.21) | 8880 | `/` |

---

## TLS Certificate Management

Traefik uses Tailscale-issued TLS certificates for each proxied domain. Certificates are managed
by a systemd timer that runs a renewal script.

### How It Works

1. The `traefik-cert-renew.service` runs `tailscale cert` for each configured domain
2. Certs are written to temp files first, then permissions are set, then atomically moved into place
3. Key files are `chmod 640` (group-readable by the `ansible` user running Traefik)
4. Cert files are `chmod 644`
5. Traefik picks up renewed certs via the file provider (no restart needed)

### Renewal Script

Deployed to `/opt/traefik/bin/cert-renew.sh` (root-owned, `0755`). Source:
[`templates/cert-renew.sh.j2`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/traefik_proxy/templates/cert-renew.sh.j2)

Key behaviors:

- Runs as root (required by `tailscale cert`)
- Uses `mktemp` → `chmod` → `mv` pattern for atomic replacement
- Non-primary domain failures are logged as warnings (non-fatal)
- Domains without active DNS rewrites will fail silently until AdGuard overrides are configured

### Systemd Timer

```text
Unit:     traefik-cert-renew.timer
Schedule: weekly (with 1h randomized delay)
Service:  traefik-cert-renew.service
Scope:    system (not user — runs as root)
```

**Manual renewal:**

```bash
sudo systemctl start traefik-cert-renew.service
```

**Check timer status:**

```bash
systemctl status traefik-cert-renew.timer
systemctl list-timers traefik-cert-renew.timer
```

### Certificate Storage

```text
/opt/traefik/certs/
├── proxy.discus-moth.ts.net/
│   ├── cert.pem     (644, ansible:ansible)
│   └── key.pem      (640, ansible:ansible)
├── sonarr.discus-moth.ts.net/
│   ├── cert.pem
│   └── key.pem
├── jellyfin.discus-moth.ts.net/
│   ├── cert.pem
│   └── key.pem
└── ... (one directory per domain)
```

!!! warning "Do not manually edit `acme.json`"
    Traefik manages this file exclusively. Deleting it will trigger re-issuance on next restart,
    which counts against Let's Encrypt rate limits (5 certificates per registered domain per week).

---

## DNS Integration

Traefik depends on AdGuard DNS rewrites to direct traffic to the proxy VM. Without these rewrites,
clients resolve service hostnames via Tailscale MagicDNS to the backend VMs directly (bypassing
the proxy).

### AdGuard Rewrites

The `traefik_dns_rewrites` list in
[`services/configs/adguard-vars.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/services/configs/adguard-vars.yml)
defines which hostnames are redirected to the proxy IP (192.168.10.20).

The `traefik_enabled` flag controls whether these rewrites are active:

```yaml
# Set true after proxy VM is deployed and Traefik is running
traefik_enabled: false
```

### Activation Sequence

1. Deploy Traefik on the proxy VM
2. Verify Traefik is running and the primary cert (`proxy.discus-moth.ts.net`) is valid
3. Set `traefik_enabled: true` in `adguard-vars.yml`
4. Run the AdGuard playbook to apply DNS rewrites
5. Run cert renewal to fetch per-service certs (now that DNS points to the proxy)
6. Verify HTTPS access for each proxied service

---

## Quadlet Container

The container is defined as a Podman Quadlet unit, templated from
[`templates/traefik.container.j2`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/traefik_proxy/templates/traefik.container.j2).

**Container configuration:**

| Setting | Value |
|---------|-------|
| **Image** | `nas.discus-moth.ts.net:5001/library/traefik:v3` (via Nexus proxy) |
| **Container name** | `traefik` |
| **User** | `ansible` (rootless) |
| **Memory limit** | 256 MB |
| **Memory reservation** | 128 MB |
| **Capabilities** | `NET_BIND_SERVICE` |
| **Restart policy** | `unless-stopped` (5s delay) |

**Volume mounts:**

| Host Path | Container Path | Mode |
|-----------|----------------|------|
| `/opt/traefik/config/traefik.yaml` | `/etc/traefik/traefik.yaml` | ro |
| `/opt/traefik/config/dynamic/` | `/etc/traefik/dynamic/` | ro |
| `/opt/traefik/certs/` | `/etc/traefik/certs/` | ro |
| `/opt/traefik/logs/` | `/var/log/traefik/` | rw |

**Published ports:**

- `80:80` (HTTP → HTTPS redirect)
- `443:443` (HTTPS TLS termination)

---

## Service Management

All commands run on the `reverse-proxy` VM as the `ansible` user (the container runs rootless).

### Status and Control

```bash
# Check service status
systemctl --user status traefik

# Start/stop/restart
systemctl --user start traefik
systemctl --user stop traefik
systemctl --user restart traefik
```

### Log Viewing

```bash
# Follow systemd journal logs
journalctl --user -u traefik -f

# View Traefik application log (JSON)
tail -f /opt/traefik/logs/traefik.log | jq .

# View access log (JSON)
tail -f /opt/traefik/logs/access.log | jq .
```

### Configuration Reload

Dynamic config changes (routers, middlewares, services) are hot-reloaded automatically via the file
provider. To force a reload:

```bash
# Touch the dynamic config file
touch /opt/traefik/config/dynamic/services.yaml
```

Static config changes (entrypoints, providers, logging) require a restart:

```bash
systemctl --user restart traefik
```

### Container Inspection

```bash
# Check running container
podman ps --filter name=traefik

# View container logs directly
podman logs traefik

# Inspect container details
podman inspect traefik
```

---

## Firewall

Defined in
[`host_vars/reverse-proxy.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/reverse-proxy.yml):

| Port | Protocol | Purpose |
|------|----------|---------|
| 80 | TCP | HTTP (redirects to HTTPS) |
| 443 | TCP | HTTPS (TLS termination) |

UFW is restricted to the Management VLAN subnet (`192.168.10.0/24`).

> **Note:** Inter-VLAN routing is handled at the network layer (UniFi firewall rules). Clients on
> other VLANs (e.g., VLAN 20 users) reach the proxy VM via routed traffic that arrives on the
> Management VLAN interface. The UFW rule restricts inbound connections to the Management subnet
> because all routed inter-VLAN traffic arrives from the gateway on that subnet.

---

## Directory Structure

```text
/opt/traefik/
├── bin/
│   └── cert-renew.sh          # TLS cert renewal script (root-owned)
├── certs/                      # Per-domain TLS certificates
│   ├── proxy.discus-moth.ts.net/
│   ├── sonarr.discus-moth.ts.net/
│   └── ...
├── config/
│   ├── traefik.yaml            # Static configuration
│   └── dynamic/
│       └── services.yaml       # Dynamic configuration (routers, services, TLS)
└── logs/
    ├── traefik.log             # Application log (JSON)
    └── access.log              # Access log (JSON)
```

---

## See Also

- [Architecture Overview](../architecture.md) — infrastructure design and VM layout
- [AdGuard Home](adguard-home.md) — DNS rewrite configuration
- [Networking](networking.md) — VLAN design and firewall rules
- [Service Endpoints](service-endpoints.md) — all service URLs and ports
- [Phase 3: Services](../deployment/phase3-services.md) — deployment order
- [Playbook Reference](../reference/playbooks.md) — complete playbook listing
- [Container Resource Management](container-resource-management.md) — Podman memory/CPU limits
- [Security](security.md) — security hardening and TLS practices
- [Tailscale Auto-Approval](../reference/tailscale-auto-approval.md) — Tailscale ACL and device approval
