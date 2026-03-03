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
| **TLS** | Let's Encrypt wildcard certificate (`*.elysium.industries`) via Cloudflare DNS-01 |
| **Config Management** | Ansible role [`roles/traefik_proxy/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/traefik_proxy) |

Traefik terminates TLS for all internal services and routes traffic based on hostname (SNI/Host header).
DNS rewrites in AdGuard redirect service hostnames to the proxy VM, where Traefik forwards requests
to the appropriate backend over plain HTTP on the LAN.

---

## Architecture

### Traffic Flow

```text
Client (LAN / Tailscale)
    |
    |  DNS query: sonarr.elysium.industries
    v
AdGuard Home (192.168.10.11)
    |  DNS rewrite -> 192.168.10.20 (proxy VM)
    v
Traefik (192.168.10.20:443)
    |  TLS termination (Let's Encrypt wildcard cert)
    |  Host header match -> route to backend
    v
Backend Service (LAN IP:port)
    e.g., media-services (192.168.30.13:8989) for Sonarr
```

### Key Design Decisions

- **File provider, not Docker provider** -- Traefik reads routes from YAML config files, not from
  container labels. No Podman socket is mounted into the container.
- **Direct LAN IPs for backends** -- Backend services are addressed by their VLAN IP, not their
  Tailscale hostname. This avoids a DNS loop: AdGuard rewrites `sonarr.elysium.industries` to the
  proxy IP, so using the same hostname as the backend URL would route back to Traefik.
- **Hot-reloadable dynamic config** -- The file provider watches the dynamic config directory. Route
  and middleware changes take effect without restarting the container.
- **Rootless Podman** -- The container runs under the `ansible` user with `NET_BIND_SERVICE` for
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

Traefik is a **Phase 3** service -- deployed after backend VMs are running and Tailscale is
authenticated on the proxy VM.

**Playbook:**
[`playbooks/services/traefik-proxy.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/services/traefik-proxy.yml)

**Role:**
[`roles/traefik_proxy/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/traefik_proxy)

**Role dependencies** (from
[`meta/main.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/traefik_proxy/meta/main.yml)):

- `common` -- base system setup, Podman environment facts
- `tailscale` -- Tailscale installation and authentication

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
| `web` | :80 | Permanent HTTP -> HTTPS redirect |
| `websecure` | :443 | TLS termination for all proxied services |

### ACME Certificate Resolver

Traefik's built-in ACME resolver obtains a wildcard certificate from Let's Encrypt using Cloudflare
DNS-01 challenge:

| Setting | Value |
|---------|-------|
| **Provider** | Let's Encrypt (production) |
| **Challenge type** | Cloudflare DNS-01 |
| **Domain** | `*.elysium.industries` |
| **Storage** | `/opt/traefik/data/acme.json` |
| **Auto-renewal** | ~30 days before expiry |
| **Contact email** | `admin@elysium.industries` |

DNS resolvers for the ACME challenge are explicitly set to `1.1.1.1:53` and `8.8.8.8:53` to bypass
the local AdGuard DNS. This is necessary because AdGuard's split-horizon rewrites would cause the
DNS-01 validation to check local records instead of public DNS.

The Cloudflare DNS API token is stored in SOPS vault (`vault_cloudflare_dns_api_token`) and passed
to the container via `secrets.env` (mode `0600`).

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

**Changes to dynamic config are hot-reloaded -- no restart needed.**

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

Certificates are managed by Traefik's ACME resolver -- a single wildcard cert (`*.elysium.industries`)
covers all proxied services. The cert is stored in `/opt/traefik/data/acme.json` and auto-renewed
approximately 30 days before expiry.

### Middlewares

Two middleware profiles are defined:

**`secure-headers`** -- Strict security headers for most services:

- HSTS (1 year, includeSubdomains, preload)
- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `X-Frame-Options: DENY`
- `Content-Security-Policy: default-src 'self'; frame-ancestors 'none'`

**`secure-headers-media`** -- Relaxed headers for services with JavaScript-heavy UIs (React SPAs, media players):

- Same HSTS and nosniff settings
- Relaxed CSP: allows `'unsafe-inline'`, `'unsafe-eval'`, `blob:`, `data:` (required for media
  playback and JS frameworks)
- `frame-ancestors 'self'` instead of `DENY` (allows embedding within same origin)

### Routers

All routers use the `websecure` entrypoint with TLS enabled. Routing is by `Host()` header match,
with path-based routing for Matrix endpoints:

| Router | Rule | Service | Middleware |
|--------|------|---------|------------|
| `matrix-well-known` | `Host(chat.elysium.industries) && PathPrefix(/.well-known/matrix)` | `elysium-synapse-wellknown` | `secure-headers` |
| `matrix-api` | `Host(chat.elysium.industries) && PathPrefix(/_matrix)` | `elysium-synapse-api` | `secure-headers` |
| `synapse-admin` | `Host(synapse-admin.elysium.industries)` | `elysium-synapse-admin` | `secure-headers-media` |
| `lk-jwt-service` | `Host(lk-jwt.elysium.industries)` | `elysium-lk-jwt` | `secure-headers` |
| `sonarr` | `Host(sonarr.elysium.industries)` | `sonarr-svc` | `secure-headers-media` |
| `radarr` | `Host(radarr.elysium.industries)` | `radarr-svc` | `secure-headers-media` |
| `prowlarr` | `Host(prowlarr.elysium.industries)` | `prowlarr-svc` | `secure-headers-media` |
| `jellyseerr` | `Host(jellyseerr.elysium.industries)` | `jellyseerr-svc` | `secure-headers-media` |
| `bazarr` | `Host(bazarr.elysium.industries)` | `bazarr-svc` | `secure-headers-media` |
| `lidarr` | `Host(lidarr.elysium.industries)` | `lidarr-svc` | `secure-headers-media` |
| `navidrome` | `Host(navidrome.elysium.industries)` | `navidrome-svc` | `secure-headers-media` |
| `byparr` | `Host(byparr.elysium.industries)` | `byparr-svc` | `secure-headers` |
| `jellyfin` | `Host(jellyfin.elysium.industries)` | `jellyfin-svc` | `secure-headers-media` |
| `tdarr` | `Host(tdarr.elysium.industries)` | `tdarr-svc` | `secure-headers-media` |
| `qbittorrent` | `Host(qbittorrent.elysium.industries)` | `qbittorrent-svc` | `secure-headers` |
| `sabnzbd` | `Host(sabnzbd.elysium.industries)` | `sabnzbd-svc` | `secure-headers-media` |
| `acme-wildcard` | `Host(traefik.elysium.industries)` | `ping@internal` | *(none)* |

> Matrix routers use priority values (`matrix-well-known: 20`, `matrix-api: 10`) to ensure
> `/.well-known/matrix` paths match before the broader `/_matrix` prefix.

### Services

All services are HTTP load balancers pointing to backend LAN IPs. Each includes a health check
(30s interval, 5s timeout) with `passHostHeader: true`.

---

## Proxied Services

| Service | Domain | Backend VM | Backend Port | Health Check |
|---------|--------|------------|--------------|--------------|
| Sonarr | `sonarr.elysium.industries` | media-services (192.168.30.13) | 8989 | `/ping` |
| Radarr | `radarr.elysium.industries` | media-services (192.168.30.13) | 7878 | `/ping` |
| Prowlarr | `prowlarr.elysium.industries` | media-services (192.168.30.13) | 9696 | `/ping` |
| Jellyseerr | `jellyseerr.elysium.industries` | media-services (192.168.30.13) | 5055 | `/` |
| Bazarr | `bazarr.elysium.industries` | media-services (192.168.30.13) | 6767 | `/` |
| Lidarr | `lidarr.elysium.industries` | media-services (192.168.30.13) | 8686 | `/ping` |
| Navidrome | `navidrome.elysium.industries` | media-services (192.168.30.13) | 4533 | `/` |
| Byparr | `byparr.elysium.industries` | media-services (192.168.30.13) | 8191 | `/` |
| Jellyfin | `jellyfin.elysium.industries` | jellyfin (192.168.30.12) | 8096 | `/health` |
| Tdarr | `tdarr.elysium.industries` | jellyfin (192.168.30.12) | 8265 | `/` |
| qBittorrent | `qbittorrent.elysium.industries` | download-clients (192.168.30.14) | 8080 | `/` |
| SABnzbd | `sabnzbd.elysium.industries` | download-clients (192.168.30.14) | 8085 | `/` |
| Matrix API | `chat.elysium.industries/_matrix/` | elysium (192.168.40.21) | 8008 | `/_matrix/client/versions` |
| Matrix well-known | `chat.elysium.industries/.well-known/matrix` | elysium (192.168.40.21) | 80 | `/.well-known/matrix/client` |
| Synapse Admin | `synapse-admin.elysium.industries` | elysium (192.168.40.21) | 8080 | `/` |
| LiveKit JWT | `lk-jwt.elysium.industries` | elysium (192.168.40.21) | 8880 | `/` |

---

## TLS Certificate Management

Traefik uses Let's Encrypt with Cloudflare DNS-01 challenge to obtain and auto-renew a wildcard
certificate for `*.elysium.industries`.

### How It Works

1. On startup, Traefik checks `/opt/traefik/data/acme.json` for existing certificates
2. If no valid cert exists (or expiry is < 30 days), Traefik initiates a DNS-01 challenge
3. Traefik creates a `_acme-challenge` TXT record via the Cloudflare API
4. Let's Encrypt validates the DNS record and issues/renews the certificate
5. The certificate is stored in `acme.json` and served immediately

### Cloudflare API Token

The DNS API token is stored in SOPS vault as `vault_cloudflare_dns_api_token` and deployed to the
container via `/opt/traefik/config/secrets.env` (mode `0600`).

**Required token scope:** `Zone:DNS:Edit` restricted to the `elysium.industries` zone.

### Environment Files

Following the `podman_app` convention, environment variables are split into two files:

| File | Mode | Contents |
|------|------|----------|
| `/opt/traefik/config/container.env` | `0644` | Non-sensitive vars (timezone) |
| `/opt/traefik/config/secrets.env` | `0600` | `CF_DNS_API_TOKEN` (Cloudflare) |

### Certificate Storage

Certificates are stored in a single JSON file:

```text
/opt/traefik/data/
└── acme.json    (0600, ansible:ansible -- contains private key)
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
2. Verify Traefik is running and the wildcard cert (`*.elysium.industries`) is valid
3. Set `traefik_enabled: true` in `adguard-vars.yml`
4. Run the AdGuard playbook to apply DNS rewrites
5. Verify HTTPS access for each proxied service

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
| `/opt/traefik/data/` | `/etc/traefik/data/` | rw |
| `/opt/traefik/logs/` | `/var/log/traefik/` | rw |

**Environment files:**

| File | Mode |
|------|------|
| `/opt/traefik/config/container.env` | `0644` |
| `/opt/traefik/config/secrets.env` | `0600` |

**Published ports:**

- `80:80` (HTTP -> HTTPS redirect)
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

UFW is restricted to the Management VLAN subnet (`192.168.10.0/24`) and the Tailscale network
(`100.64.0.0/10`). Legacy flat-LAN rules (`192.168.0.0/24`) remain until `ufw_remove_legacy` is
enabled globally.

No `ufw_cross_vlan_rules` are needed on the proxy VM. Clients on the Management VLAN and Tailscale
reach the proxy directly. The proxy **initiates outbound connections** to backends on other VLANs
(Media VLAN 30, Communications VLAN 40) -- outbound traffic is allowed by UFW's default `allow
outgoing` policy, so no inbound cross-VLAN rules are required on the proxy side. Backend VMs define
their own `ufw_cross_vlan_rules` to accept connections from the Management VLAN where the proxy
resides.

---

## Directory Structure

```text
/opt/traefik/
├── config/
│   ├── traefik.yaml            # Static configuration
│   ├── container.env           # Non-sensitive env vars (0644)
│   ├── secrets.env             # Cloudflare API token (0600)
│   └── dynamic/
│       └── services.yaml       # Dynamic configuration (routers, services, TLS)
├── data/
│   └── acme.json               # ACME certificate storage (0600, auto-managed)
└── logs/
    ├── traefik.log             # Application log (JSON)
    └── access.log              # Access log (JSON)
```

---

## See Also

- [Architecture Overview](../architecture.md) -- infrastructure design and VM layout
- [AdGuard Home](adguard-home.md) -- DNS rewrite configuration
- [Networking](networking.md) -- VLAN design and firewall rules
- [Service Endpoints](service-endpoints.md) -- all service URLs and ports
- [Phase 3: Services](../deployment/phase3-services.md) -- deployment order
- [Playbook Reference](../reference/playbooks.md) -- complete playbook listing
- [Container Resource Management](container-resource-management.md) -- Podman memory/CPU limits
- [Security](security.md) -- security hardening and TLS practices
- [Tailscale Auto-Approval](../reference/tailscale-auto-approval.md) -- Tailscale ACL and device approval
