# qBittorrent

> Torrent download client, routed through a Gluetun VPN sidecar (Private Internet Access)

| Field | Value |
|-------|-------|
| **Runs on** | k3s `media` namespace on `k8s-media` |
| **Access** | `https://qbittorrent.elysium.industries` |
| **Port** | 8080 |
| **Repo** | `jellybuntu-helm` -> `clusters/jellybuntu/media/qbittorrent.yaml` |

## Key Config

- Pod runs three containers: `app` (qBittorrent), `gluetun` (VPN), and `port-sync` (helper)
- All outbound traffic from `app` flows through `gluetun`'s network stack — Gluetun requires
  `NET_ADMIN` capability and a `/dev/net/tun` host path mount
- VPN provider: Private Internet Access (OpenVPN) with port forwarding enabled; credentials
  come from the `vpn-credentials` secret
- `port-sync` watches Gluetun's forwarded port file and patches qBittorrent's listening port
  automatically via inotify
- Allowed subnets for direct access (bypass VPN): `10.42.0.0/16`, `10.43.0.0/16`,
  `192.168.30.0/24`, `100.64.0.0/10`
- Memory: 1 Gi request / 2 Gi limit

## Common Operations

```bash
# Restart (restarts all three containers in the pod)
kubectl rollout restart deployment/qbittorrent -n media

# Logs — choose container
kubectl logs -f deployment/qbittorrent -n media -c app
kubectl logs -f deployment/qbittorrent -n media -c gluetun
kubectl logs -f deployment/qbittorrent -n media -c port-sync

# Shell into main app
kubectl exec -it deployment/qbittorrent -n media -c app -- /bin/sh
```
