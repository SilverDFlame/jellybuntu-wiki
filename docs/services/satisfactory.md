# Satisfactory Server

> Dedicated Satisfactory game server with CPU core pinning

| Field | Value |
|-------|-------|
| **Runs on** | VM `satisfactory-server` (VMID 200), `192.168.40.11` |
| **Access** | `satisfactory-server.discus-moth.ts.net:7777` (Tailscale, UDP) |
| **Ports** | 7777 UDP (game traffic), 7777 TCP (server API), 8888 TCP (Server Manager HTTPS) |
| **Repo** | [`roles/satisfactory/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/satisfactory) and [`host_vars/satisfactory-server.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/satisfactory-server.yml) |

## Key Config

- Runs as a native systemd service (not a container) — installed via SteamCMD
- **Proxmox-level CPU pinning**: host cores 4–7 pinned to this VM (EPYC 7313P)
  - Cores 0–3 reserved for future Minecraft server
- **Guest-level CPU affinity**: all 4 visible vCPUs (0–3) assigned to the game process
- Nice priority `-10` (high) and `nofile` limit 65536 for the service unit
- VM resources: 4 vCPUs, 8 GB RAM, 60 GB disk; `cpu_units = 2048` (high scheduler priority)
- Legacy ports 15000/15777 removed in Satisfactory 1.0+

## Common Operations

```bash
# Deploy / reconfigure
./bin/runtime/ansible-run.sh playbooks/services/satisfactory.yml

# Service status
ssh satisfactory-server.discus-moth.ts.net sudo systemctl status satisfactory

# View live logs
ssh satisfactory-server.discus-moth.ts.net sudo journalctl -fu satisfactory

# Restart
ssh satisfactory-server.discus-moth.ts.net sudo systemctl restart satisfactory

# Update game files (SteamCMD)
ssh satisfactory-server.discus-moth.ts.net sudo systemctl stop satisfactory
ssh satisfactory-server.discus-moth.ts.net /usr/games/steamcmd +login anonymous \
  +app_update 1690800 validate +quit
ssh satisfactory-server.discus-moth.ts.net sudo systemctl start satisfactory
```
