# Deluge

> Torrent download client for the *arr apps, routed through a Gluetun VPN sidecar (AirVPN WireGuard)

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace on `k8s-media` |
| **Access** | `https://deluge.elysium.industries` |
| **Port** | 8112 (web UI) |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/deluge.yaml` |

Replaces the former qBittorrent + Private Internet Access setup. Sonarr/Radarr/Lidarr
point at Deluge as their torrent download client.

## Key Config

- Pod runs two containers: `app` (Deluge) and `gluetun` (VPN). All of `app`'s outbound
  traffic flows through `gluetun`'s network stack.
- VPN provider: **AirVPN**, WireGuard custom mode. The endpoint comes from the
  `airvpn-endpoint-active` ConfigMap (shared across sibling tenants on the same AirVPN
  account); WireGuard credentials are remapped per-key from `vpn-credentials` so each
  tenant uses a distinct device key — the same WG private key cannot connect to AirVPN
  twice at once.
- `FIREWALL_VPN_INPUT_PORTS` is the AirVPN-allocated forwarded port bound to this device.
- Allowed subnets for direct LAN access (bypass VPN): `10.42.0.0/16`, `10.43.0.0/16`,
  `192.168.30.0/24`, `100.64.0.0/10`.
- Passwords (`SERVICES_ADMIN_PASSWORD`, `DELUGE_DAEMON_PASSWORD`) come from `media-secrets`.
- Memory: 512 Mi request / 2 Gi limit.

!!! note "Two Deluge instances exist"
    This in-cluster Deluge handles direct grabs. A **separate** Deluge runs on the Ultra.cc
    seedbox as part of the [Seedbox Orchestrator](seedbox-orchestrator.md) transport pipeline.
    They are unrelated daemons.

## Common Operations

```bash
# Restart (restarts both containers in the pod)
kubectl rollout restart deployment/deluge -n media

# Logs — choose container
kubectl logs -f deployment/deluge -n media -c app
kubectl logs -f deployment/deluge -n media -c gluetun

# Confirm the VPN tunnel + forwarded port
kubectl logs deployment/deluge -n media -c gluetun | grep -iE 'wireguard|forwarded port'

# Shell into the app
kubectl exec -it deployment/deluge -n media -c app -- /bin/sh
```

## Gotchas

- Deluge `State=Error "Missing or invalid torrent data"` on a NAS-side pull means the
  orchestrator injected the `.torrent` mid-rclone; the on-disk file is usually complete —
  force a recheck. See the seedbox-orchestrator notes.
- Pings to the Cilium L2 LB VIP always TTL-loop (cosmetic) — use `curl`/`nc` to test reachability.
