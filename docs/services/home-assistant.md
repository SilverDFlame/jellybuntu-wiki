# Home Assistant

> Smart home automation hub — device integrations, automations, and dashboards

| Field | Value |
|-------|-------|
| **Runs on** | VM `home-assistant` (VMID 100), `192.168.20.10` |
| **Access** | `http://home-assistant.discus-moth.ts.net:8123` (Tailscale only) |
| **Port** | 8123 |
| **Repo** | [`roles/podman_app/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/podman_app) and [`host_vars/home-assistant.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/home-assistant.yml) |

## Key Config

- Runs as a rootless Podman container; config at `/opt/homeassistant/config` (container UID 3000)
- IoT VLAN (192.168.20.0/24) — isolated from Media and Management VLANs
- No Traefik reverse proxy — access is Tailscale-only via direct port 8123
- VM resources: 2 vCPUs, 2 GB RAM, 40 GB disk (startup order 5)
- Releases checked weekly (Monday); updates applied manually after review

## Common Operations

```bash
# Deploy / reconfigure
./bin/runtime/ansible-run.sh playbooks/services/home-assistant.yml

# Check container status
ssh home-assistant.discus-moth.ts.net podman ps --filter name=homeassistant

# View logs
ssh home-assistant.discus-moth.ts.net podman logs -f homeassistant

# Restart
ssh home-assistant.discus-moth.ts.net systemctl --user restart podman-homeassistant

# Shell into container
ssh home-assistant.discus-moth.ts.net podman exec -it homeassistant bash
```
