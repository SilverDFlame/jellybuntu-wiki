# k3s Namespace Reference

Complete service inventory for the k3s cluster, organized by namespace.

## Infrastructure Namespaces

| Namespace | Component | Version | Notes |
|---|---|---|---|
| `traefik-system` | Traefik | v39.0.5 | LoadBalancer VIP on k8s-net; all ingress routes here |
| `metallb-system` | MetalLB | v0.15.3 | L2 mode; pool `192.168.30.200/29` |
| `nfs-system` | nfs-subdir-external-provisioner | v4.0.18 | StorageClass: `nfs-client`; NAS at `192.168.30.15` |
| `kube-system` | nvidia-device-plugin | v0.18.2 | GPU time-slicing: 1 physical → 2 virtual on k8s-gpu |

## media Namespace (k8s-media, `.42`)

| Service | Port | URL | Access |
|---|---|---|---|
| sonarr | 8989 | sonarr.elysium.industries | IP restricted |
| radarr | 7878 | radarr.elysium.industries | IP restricted |
| lidarr | 8686 | lidarr.elysium.industries | IP restricted |
| prowlarr | 9696 | prowlarr.elysium.industries | IP restricted |
| jellyseerr | 5055 | seerr.elysium.industries | Public |
| bazarr | 6767 | bazarr.elysium.industries | IP restricted |
| navidrome | 4533 | navidrome.elysium.industries | Public |
| byparr | 8191 | byparr.elysium.industries | IP restricted |
| qbittorrent | 8080 | qbittorrent.elysium.industries | IP restricted |
| sabnzbd | 8080 | sabnzbd.elysium.industries | IP restricted |
| recyclarr | — | — | No ingress; CronJob runs 04:00 UTC |
| unpackerr | — | — | No ingress |

## gpu Namespace (k8s-gpu, `.41`)

| Service | Port | URL | Access |
|---|---|---|---|
| jellyfin | 8096 | jellyfin.elysium.industries | Public |
| tdarr | 8265 / 8266 | tdarr.elysium.industries | IP restricted |

## matrix Namespace (k8s-ops, `.44`)

| Service | Port | URL | Access |
|---|---|---|---|
| synapse | 8008 | chat.elysium.industries | Public (federation) |
| livekit | 7880 | livekit.elysium.industries | Public |
| lk-jwt | 8080 | lk-jwt.elysium.industries | IP restricted |
| coturn | 3478 | — | STUN/TURN; hostNetwork; no HTTP ingress |
| synapse-admin | 8080 | synapse-admin.elysium.industries | IP restricted |

## teamspeak Namespace (k8s-ops, `.44`)

| Protocol | Port | Purpose |
|---|---|---|
| UDP | 9987 | Voice |
| TCP | 30033 | File transfer |
| TCP | 10011 | ServerQuery |

No HTTP ingress — clients connect directly to MetalLB VIP.

## In-Cluster DNS

Services resolve within the cluster at:

```text
http://<service>.<namespace>.svc.cluster.local:<port>
```

Examples:

```text
http://sonarr.media.svc.cluster.local:8989
http://radarr.media.svc.cluster.local:7878
http://prowlarr.media.svc.cluster.local:9696
http://jellyfin.gpu.svc.cluster.local:8096
```

Short form works within the same namespace (e.g. `http://sonarr:8989` from another `media` pod).

## IP Restriction Policy

"IP restricted" = Traefik `admin-ipallowlist` middleware applied. Allowed CIDRs:

| Range | Description |
|---|---|
| `192.168.30.0/24` | Media VLAN (local network) |
| `100.64.0.0/10` | Tailscale CGNAT range |

Middleware defined in [`clusters/jellybuntu/media/middleware.yaml`](https://github.com/SilverDFlame/jellybuntu-helm/blob/main/clusters/jellybuntu/media/middleware.yaml).

## See Also

- [jellybuntu-helm Repo Layout](helm-repo.md)
- [k3s Cluster Operations](k3s-cluster.md)
