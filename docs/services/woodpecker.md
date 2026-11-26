# Woodpecker CI

> CI/CD pipeline runner for jellybuntu and jellybuntu-wiki repositories

| Field | Value |
|-------|-------|
| **Runs on** | `woodpecker` VM (rootless Podman, not k3s) |
| **Access** | `https://automation.discus-moth.ts.net` |
| **Port** | 8000 (web UI), 9000 (agent gRPC) |
| **Repo** | `jellybuntu` -> `playbooks/services/woodpecker-ci.yml`, `host_vars/automation.yml` |

## Key Config

- Server and agent run as a Podman pod (`ci-pod`) sharing a network namespace — the agent
  reaches the server on `localhost:9000`
- **Forge: Forgejo** (`https://forgejo.discus-moth.ts.net`) since 2026-11-26 (Forgejo P2); the
  driver is `woodpecker_forge: forgejo` in `host_vars/automation.yml`. Login is Forgejo OAuth (app
  `Woodpecker CI` owned by `SilverDFlame`); WOODPECKER_OPEN is false (no self-registration)
- GitHub no longer triggers pipelines: the GitHub webhooks are inactive and the GitHub copies of
  `jellybuntu` and `jellybuntu-wiki` are frozen push-mirror targets until Forgejo P4
- Agent uses the Podman socket at `/run/user/<uid>/podman/podman.sock` mapped as a Docker
  socket — pipeline containers are spawned on `woodpecker-net`
- Max concurrent workflows: 4 (`WOODPECKER_MAX_WORKFLOWS`)
- Webhooks: one Forgejo webhook per repo, delivered over the LAN to `http://192.168.10.17:8000`
  (`WOODPECKER_EXPERT_WEBHOOK_HOST`; the Forgejo webhook allowlist admits only that host). If a
  repo fires two pipelines per event, or none, check the repo's Settings, Webhooks in Forgejo
- Public repos clone with credentials too (`WOODPECKER_AUTHENTICATE_PUBLIC_REPOS=true`), so the
  public wiki repo does not fail its clone step
- Tailscale Funnel still exposes the old GitHub webhook endpoint; it is unused and is removed at
  Forgejo P4
- Known gap: pipeline status may not show on Forgejo commits and PRs while container egress DNS
  is flaky ([jellybuntu#468](https://forgejo.discus-moth.ts.net/SilverDFlame/jellybuntu/issues/468));
  the Woodpecker UI is authoritative

## Common Operations

```bash
# Check status (run on woodpecker VM)
systemctl --user status woodpecker-server woodpecker-agent

# View logs
journalctl --user -u woodpecker-server -f
journalctl --user -u woodpecker-agent -f

# Restart
systemctl --user restart woodpecker-server
systemctl --user restart woodpecker-agent
```
