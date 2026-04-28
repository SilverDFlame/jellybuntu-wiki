
# Service Endpoints

All service URLs and access methods for the Jellybuntu homelab.

## Quick Reference

### k3s Services via Traefik (MetalLB VIP 192.168.30.200)

All public-facing k3s services terminate TLS at Traefik with `*.elysium.industries` certificates.

#### Media Namespace (k8s-media node, 192.168.30.42)

| Service | URL |
|---------|-----|
| Sonarr | https://sonarr.elysium.industries |
| Radarr | https://radarr.elysium.industries |
| Lidarr | https://lidarr.elysium.industries |
| Prowlarr | https://prowlarr.elysium.industries |
| Jellyseerr | https://seerr.elysium.industries |
| Bazarr | https://bazarr.elysium.industries |
| Navidrome | https://navidrome.elysium.industries |
| Byparr | https://byparr.elysium.industries |
| qBittorrent | https://qbittorrent.elysium.industries |
| SABnzbd | https://sabnzbd.elysium.industries |

#### GPU Namespace (k8s-gpu node, 192.168.30.41)

| Service | URL | Notes |
|---------|-----|-------|
| Jellyfin | https://jellyfin.elysium.industries | Public |
| Tdarr | https://tdarr.elysium.industries | IP restricted: 192.168.30.0/24 + Tailscale |

#### Matrix Namespace (k8s-ops node, 192.168.30.44)

| Service | URL | Notes |
|---------|-----|-------|
| Synapse | https://chat.elysium.industries | Public |
| LiveKit | https://livekit.elysium.industries | Public |
| LiveKit JWT | https://lk-jwt.elysium.industries | Public |
| Synapse Admin | https://synapse-admin.elysium.industries | IP restricted |

### Standalone VM Services (Ansible-managed)

| Service | URL |
|---------|-----|
| Home Assistant | http://home-assistant.discus-moth.ts.net:8123 |
| Grafana | http://monitoring.discus-moth.ts.net:3000 |
| Prometheus | http://monitoring.discus-moth.ts.net:9090 |
| Alertmanager | http://monitoring.discus-moth.ts.net:9093 |
| Woodpecker CI | http://automation.discus-moth.ts.net:8000 |
| Nexus Repository | http://nas.discus-moth.ts.net:8081 |
| Nexus Registry | nas.discus-moth.ts.net:5001 |
| Docs | http://nas.discus-moth.ts.net:8082 |
| UniFi Controller | https://unifi-controller.discus-moth.ts.net:8443 |
| Lancache | http://lancache.discus-moth.ts.net:80 |
| Satisfactory | satisfactory-server.discus-moth.ts.net:7777 |
| Proxmox | https://jellybuntu.discus-moth.ts.net:8006 |

## In-Cluster DNS

Services within the cluster communicate via Kubernetes DNS without going through Traefik.

| Service | In-cluster URL |
|---------|---------------|
| Sonarr | http://sonarr.media.svc.cluster.local:8989 |
| Radarr | http://radarr.media.svc.cluster.local:7878 |
| Lidarr | http://lidarr.media.svc.cluster.local:8686 |
| Prowlarr | http://prowlarr.media.svc.cluster.local:9696 |
| SABnzbd | http://sabnzbd.media.svc.cluster.local:8080 |
| Jellyfin | http://jellyfin.gpu.svc.cluster.local:8096 |
| Synapse | http://synapse.matrix.svc.cluster.local:8008 |

## Deployment Types

| Service | Deployment | Namespace / Location |
|---------|------------|---------------------|
| Sonarr, Radarr, Lidarr, Prowlarr | HelmRelease (Flux) | k8s `media` |
| Bazarr, Jellyseerr, Navidrome | HelmRelease (Flux) | k8s `media` |
| SABnzbd, qBittorrent, Byparr | HelmRelease (Flux) | k8s `media` |
| Unpackerr, Recyclarr | HelmRelease (Flux) | k8s `media` |
| Jellyfin | HelmRelease (Flux) | k8s `gpu` |
| Tdarr | HelmRelease (Flux) | k8s `gpu` |
| Synapse, LiveKit, lk-jwt, coturn, Synapse Admin | HelmRelease (Flux) | k8s `matrix` |
| Traefik | HelmRelease (Flux) | k8s `traefik-system` |
| Home Assistant | Quadlet (rootless Podman) | home-assistant VM |
| Satisfactory | Native systemd | satisfactory VM |
| Monitoring stack | Quadlet (rootless Podman) | monitoring VM |
| Woodpecker CI | Quadlet (rootless Podman) | automation VM |
| Nexus Repository | Quadlet (rootless Podman) | nas VM |
| Lancache | Quadlet (rootful Podman) | lancache VM |
| UniFi Controller | Quadlet (rootless Podman) | unifi-controller VM |

## Service Management

### k3s Services (kubectl)

```bash
# Get pods in a namespace
kubectl get pods -n media
kubectl get pods -n gpu
kubectl get pods -n matrix

# Logs
kubectl logs -n <namespace> deployment/<name> -f

# Restart a deployment
kubectl rollout restart deployment/<name> -n <namespace>

# Shell into a container
kubectl exec -it -n <namespace> deployment/<name> -- /bin/bash

# Resource usage
kubectl top pods -n <namespace>
```

### Flux Operations

```bash
# Force reconcile a HelmRelease
flux reconcile helmrelease <name> -n <namespace>

# Force reconcile a kustomization (and its git source)
flux reconcile kustomization <name> -n flux-system --with-source

# Check Flux status
flux get helmreleases -A
flux get kustomizations
```

### Standalone VM Services (Quadlet)

All containerized standalone VM services use rootless Podman with Quadlet (systemd user services).

```bash
# Check status
systemctl --user status <service>

# View logs
journalctl --user -u <service> -f

# Restart
systemctl --user restart <service>
```

#### Monitoring VM (192.168.10.16)

```bash
ssh -i ~/.ssh/ansible_homelab ansible@monitoring.discus-moth.ts.net
systemctl --user status prometheus alertmanager grafana
systemctl --user restart prometheus alertmanager grafana
```

#### Woodpecker CI VM (192.168.10.17)

```bash
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net
systemctl --user status woodpecker-server woodpecker-agent
systemctl --user restart woodpecker-server woodpecker-agent
```

#### UniFi Controller VM (192.168.10.19)

```bash
ssh -i ~/.ssh/ansible_homelab ansible@unifi-controller.discus-moth.ts.net
systemctl --user status unifi-mongodb unifi-app
systemctl --user restart unifi-mongodb unifi-app
```

#### Home Assistant VM

```bash
ssh -i ~/.ssh/ansible_homelab ansible@home-assistant.discus-moth.ts.net
systemctl --user status home-assistant
```

## Port Reference

### k3s Cluster Entry Points

| Entry Point | Address | Notes |
|-------------|---------|-------|
| Traefik HTTPS | 192.168.30.200:443 (MetalLB VIP) | All `*.elysium.industries` services |
| Traefik HTTP | 192.168.30.200:80 | Redirects to HTTPS |

### k3s Node Direct Ports (hostPort / hostNetwork)

| Service | Node | Port | Protocol | Purpose |
|---------|------|------|----------|---------|
| LiveKit WebRTC TCP | k8s-ops (.44) | 7881 | TCP | WebRTC |
| LiveKit media | k8s-ops (.44) | 50000-50020 | UDP | WebRTC media |
| coturn TURN/STUN | k8s-ops (.44) | 3478 | TCP+UDP | TURN/STUN |

### Standalone VM Ports

| Service | VM IP | Port | Protocol | Purpose |
|---------|-------|------|----------|---------|
| Home Assistant | 192.168.20.10 | 8123 | HTTP | Web UI |
| Satisfactory | 192.168.40.11 | 7777 | TCP+UDP | Game |
| Prometheus | 192.168.10.16 | 9090 | HTTP | Web UI |
| Alertmanager | 192.168.10.16 | 9093 | HTTP | Web UI |
| Grafana | 192.168.10.16 | 3000 | HTTP | Web UI |
| Woodpecker Server | 192.168.10.17 | 8000 | HTTP | Web UI |
| Woodpecker Agent gRPC | 192.168.10.17 | 9000 | gRPC | Agent |
| Lancache | 192.168.40.18 | 80 | HTTP | Cache |
| Lancache SNI | 192.168.40.18 | 443 | HTTPS | SNI proxy |
| UniFi | 192.168.10.19 | 8443 | HTTPS | Web UI |
| UniFi inform | 192.168.10.19 | 8080 | HTTP | Device inform |
| UniFi STUN | 192.168.10.19 | 3478 | UDP | STUN |
| Nexus | 192.168.30.15 | 8081 | HTTP | Web UI |
| Nexus Registry | 192.168.30.15 | 5001 | HTTP | Container registry |

## Download Client Configuration (Arr Stack)

qBittorrent and SABnzbd are in the `media` namespace. Configure in Sonarr/Radarr:

### qBittorrent

- Host: `http://qbittorrent.media.svc.cluster.local:8080` (in-cluster)
- Port: 8080

### SABnzbd

- Host: `http://sabnzbd.media.svc.cluster.local:8080` (in-cluster)
- Port: 8080
- API Key: found in SABnzbd Config → General → Security

## SSH Access

```bash
# Via Tailscale
ssh -i ~/.ssh/ansible_homelab ansible@<hostname>.discus-moth.ts.net

# Via local IP
ssh -i ~/.ssh/ansible_homelab ansible@192.168.<vlan>.<ip>
```

k3s nodes (for diagnostics only — do not manually change state):

```bash
ssh -i ~/.ssh/ansible_homelab ansible@192.168.30.40  # k8s-control
ssh -i ~/.ssh/ansible_homelab ansible@192.168.30.41  # k8s-gpu
ssh -i ~/.ssh/ansible_homelab ansible@192.168.30.42  # k8s-media
ssh -i ~/.ssh/ansible_homelab ansible@192.168.30.43  # k8s-net
ssh -i ~/.ssh/ansible_homelab ansible@192.168.30.44  # k8s-ops
```

## Proxmox Web UI

- **URL**: https://jellybuntu.discus-moth.ts.net:8006 or https://192.168.0.1:8006
- **User**: root@pam or ansible@pve
- Requires local network or Tailscale access

## Troubleshooting Access

### Can't Access a k3s Service

1. Check pod: `kubectl get pods -n <namespace>`
2. Check IngressRoute: `kubectl get ingressroute -n <namespace>`
3. Check Traefik: `kubectl get pods -n traefik-system`
4. Verify MetalLB VIP is reachable: `ping 192.168.30.200`

### Can't Access a Standalone VM Service

1. Check service: `systemctl --user status <service>`
2. Check container: `export XDG_RUNTIME_DIR=/run/user/$(id -u) && podman ps`
3. Verify firewall: `sudo ufw status`
4. Check port: `sudo ss -tlnp | grep <port>`

### Can't SSH

1. Verify key: `ls ~/.ssh/ansible_homelab`
2. Add to agent: `ssh-add ~/.ssh/ansible_homelab`
3. Use `-o IdentitiesOnly=yes` if agent has many keys loaded

## See Also

- [Networking Configuration](networking.md)
- [Jellyfin Setup](jellyfin-setup.md)
- [Tdarr Setup](tdarr-setup.md)
- [Matrix Setup](matrix-setup.md)
- [Troubleshooting Guide](../maintenance/troubleshooting.md)
