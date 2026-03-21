# Woodpecker CI

> CI/CD pipeline runner for jellybuntu and jellybuntu-wiki repositories

| Field | Value |
|-------|-------|
| **Runs on** | `woodpecker` VM (rootless Podman, not k3s) |
| **Access** | `https://automation.discus-moth.ts.net` |
| **Port** | 8000 (web UI), 9000 (agent gRPC) |
| **Repo** | `jellybuntu` -> `playbooks/services/woodpecker-ci.yml` |

## Key Config

- Server and agent run as a Podman pod (`ci-pod`) sharing a network namespace — the agent
  reaches the server on `localhost:9000`
- GitHub OAuth integration only; WOODPECKER_OPEN is false (no self-registration)
- Agent uses the Podman socket at `/run/user/<uid>/podman/podman.sock` mapped as a Docker
  socket — pipeline containers are spawned on `woodpecker-net`
- Max concurrent workflows: 4 (`WOODPECKER_MAX_WORKFLOWS`)
- Webhook endpoint for GitHub: `https://automation.discus-moth.ts.net/hook`
- Tailscale Funnel is configured to expose the webhook endpoint externally

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
