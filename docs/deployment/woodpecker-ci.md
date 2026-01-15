# Woodpecker CI Deployment

Deployment guide for Woodpecker CI continuous integration server.

## Overview

Woodpecker CI provides automated testing, linting, and deployment pipelines for the Jellybuntu infrastructure. It runs
as a rootless Podman deployment on a dedicated VM with GitHub integration via OAuth.

**VM**: VMID 600 (192.168.0.17)
**Hostname**: automation.discus-moth.ts.net
**Resources**: 2 cores, 8GB RAM, 32GB disk

## Prerequisites

- Phase 1 complete (VM provisioned)
- Phase 2 complete (Tailscale configured)
- GitHub OAuth App configured
- Secrets in vault:
  - `vault_woodpecker_github_client`
  - `vault_woodpecker_github_secret`
  - `vault_woodpecker_agent_secret`
  - `vault_woodpecker_webhook_secret`

## Deployment

### Option 1: Via Phase C (Recommended)

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase-c-advanced.yml
```

### Option 2: Individual Playbook

```bash
./bin/runtime/ansible-run.sh playbooks/core/18-configure-woodpecker-ci-role.yml
```

## GitHub OAuth Setup

### Create OAuth App

1. Go to GitHub Settings > Developer Settings > OAuth Apps
2. Click "New OAuth App"
3. Configure:
   - **Application name**: Jellybuntu Woodpecker CI
   - **Homepage URL**: `https://automation.discus-moth.ts.net`
   - **Authorization callback URL**: `https://automation.discus-moth.ts.net/authorize`
4. Save Client ID and generate Client Secret
5. Add to vault:

```bash
sops group_vars/all.sops.yaml
```

```yaml
vault_woodpecker_github_client: "your-client-id"
vault_woodpecker_github_secret: "your-client-secret"
```

### Generate Agent Secret

```bash
openssl rand -hex 32
```

Add to vault as `vault_woodpecker_agent_secret`.

## Tailscale Funnel Setup

Woodpecker requires a publicly accessible webhook endpoint for GitHub. Tailscale Funnel provides this.

### Enable Funnel (One-Time)

SSH to the Woodpecker VM and enable Funnel:

```bash
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net
tailscale funnel 443
```

### Verify Funnel

```bash
tailscale funnel status
```

Should show port 443 forwarded to localhost:8000.

## GitHub Webhook Configuration

1. Go to repository Settings > Webhooks
2. Click "Add webhook"
3. Configure:
   - **Payload URL**: `https://automation.discus-moth.ts.net/hook`
   - **Content type**: `application/json`
   - **Secret**: (use `vault_woodpecker_webhook_secret` value)
   - **Events**: Push, Pull requests, Create (for tags)
4. Save and verify delivery

## Post-Deployment Steps

### 1. Access Web UI

Open https://automation.discus-moth.ts.net and login with GitHub.

### 2. Activate Repository

1. Click "Add repository"
2. Find and activate `jellybuntu`
3. Repository will sync `.woodpecker/` pipelines

### 3. Configure Repository Secrets

In Woodpecker UI, go to repository Settings > Secrets:

| Secret Name | Description |
|-------------|-------------|
| `sops_age_key` | Age private key for SOPS decryption |
| `ssh_private_key` | SSH key for VM access |
| `github_token` | GitHub PAT for automated commits |

### 4. Enable Trusted Mode

For pipelines that need volume mounts (like Packer builds):

1. Repository Settings > General
2. Enable "Trusted" checkbox
3. Save

## Network Configuration

Pipeline containers need network access for operations like `ansible-galaxy install`, `pip install`, or pulling container
images. This is configured via the `WOODPECKER_BACKEND_DOCKER_NETWORK` environment variable.

### Why woodpecker-net?

The agent uses Podman to spawn pipeline containers. By default, these containers have no network access. Setting
`WOODPECKER_BACKEND_DOCKER_NETWORK: woodpecker-net` attaches pipeline containers to the `woodpecker-net` network,
enabling internet access.

### Verifying Network Configuration

```bash
# Check if network exists
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net
podman network inspect woodpecker-net

# Test from a pipeline (add to .woodpecker/ci.yml temporarily)
- name: test-network
  image: alpine
  commands:
    - apk add curl
    - curl -I https://github.com
```

### Troubleshooting Network Issues

If pipeline steps fail with "network unreachable":

1. Verify the network exists: `podman network ls`
2. Check agent config includes `WOODPECKER_BACKEND_DOCKER_NETWORK`
3. Restart the agent: `systemctl --user restart woodpecker-agent`

## Architecture

```text
┌─────────────────────────────────────────────────┐
│ Woodpecker CI VM (VMID 600, 192.168.0.17)       │
│                                                 │
│  ┌─────────────────┐  ┌─────────────────────┐  │
│  │ woodpecker-     │  │ woodpecker-agent    │  │
│  │ server          │  │                     │  │
│  │ :8000 (Web UI)  │──│ Connects to server  │  │
│  │ :9000 (gRPC)    │  │ via gRPC            │  │
│  └─────────────────┘  └─────────────────────┘  │
│          │                     │               │
│          │                     │               │
│  SQLite DB             Podman socket           │
│  /opt/woodpecker/      /run/user/1001/podman/  │
│                                                 │
└─────────────────────────────────────────────────┘
          │
          │ Tailscale Funnel (:443 → :8000)
          │
    ┌─────┴─────┐
    │  GitHub   │
    │ Webhooks  │
    └───────────┘
```

## Pipelines

The repository includes these pipelines in `.woodpecker/`:

| Pipeline | Trigger | Purpose |
|----------|---------|---------|
| `ci.yml` | Push, PR | Lint, validate, security scan |
| `drift-detection.yml` | Daily 4AM UTC | OpenTofu drift detection |
| `packer-build.yml` | Manual, tags | Golden image rotation |
| `ssh-keys.yml` | Manual | Deploy SSH authorized keys to all hosts |
| `docs.yml` | docs/** changes | MkDocs site build |

## Triggering Manual Pipelines

Manual pipelines (`packer-build` and `ssh-keys`) can be triggered via GitHub Actions for a better UX.

### Via GitHub Actions (Recommended)

1. Go to GitHub repository > Actions
2. Select "Trigger Woodpecker Pipeline"
3. Click "Run workflow"
4. Select the pipeline from the dropdown:
   - **packer-build**: Build golden image with rotation
   - **ssh-keys**: Deploy SSH authorized keys
5. For `ssh-keys`, optionally specify:
   - **Ansible tags**: e.g., `proxmox,vms,ssh_keys`
   - **Ansible limit**: e.g., `jellyfin,media-services`
6. Click "Run workflow"

### Via Woodpecker UI

Direct Woodpecker UI triggers require specifying the `WORKFLOW` parameter:

1. Go to Woodpecker UI > Repository > Actions
2. Click "Run pipeline"
3. Add variable: `WORKFLOW=packer-build` or `WORKFLOW=ssh-keys`
4. For `ssh-keys`, optionally add:
   - `ANSIBLE_TAGS=proxmox,vms`
   - `ANSIBLE_LIMIT=jellyfin,media-services`
5. Click "Run"

**Note**: Without the `WORKFLOW` parameter, manual pipelines will not run.

### GitHub Secrets Required

Configure these secrets in GitHub repository settings for the Actions workflow:

| Secret | Description | How to obtain |
|--------|-------------|---------------|
| `WOODPECKER_SERVER` | Woodpecker URL | `https://automation.discus-moth.ts.net` |
| `WOODPECKER_TOKEN` | Personal access token | Woodpecker UI > User Settings > CLI & API |
| `WOODPECKER_REPO_ID` | Repository ID | Found in Woodpecker repo settings URL |

### Troubleshooting Triggers

#### Missing required secrets error

GitHub secrets not configured. Go to repository Settings > Secrets and variables > Actions
and add `WOODPECKER_SERVER`, `WOODPECKER_TOKEN`, and `WOODPECKER_REPO_ID`.

#### HTTP 401 Unauthorized

Invalid or expired Woodpecker token.
Generate a new token in Woodpecker UI > User Settings > CLI & API.

#### HTTP 404 Not Found

Wrong repository ID.
Find the correct ID in the Woodpecker repo settings URL (e.g., `/repos/123` means ID is `123`).

#### Pipeline triggered but nothing runs in Woodpecker

The `WORKFLOW` parameter doesn't match. Verify the pipeline files have
`evaluate: 'CI_PIPELINE_FORGE_PARAMETER_WORKFLOW == "pipeline-name"'` in their `when` block.

#### Connection refused or timeout

Woodpecker server unreachable. Verify:

- Tailscale Funnel is running: `tailscale funnel status`
- Server is up: `systemctl --user status woodpecker-server`

## Service Management

### Check Status

```bash
ssh -i ~/.ssh/ansible_homelab ansible@automation.discus-moth.ts.net
systemctl --user status woodpecker-server woodpecker-agent
```

### View Logs

```bash
journalctl --user -u woodpecker-server -f
journalctl --user -u woodpecker-agent -f
```

### Restart Services

```bash
systemctl --user restart woodpecker-server woodpecker-agent
```

## Validation

After deployment, verify:

1. **Web UI accessible**: https://automation.discus-moth.ts.net
2. **GitHub login works**: Can authenticate via OAuth
3. **Repository synced**: jellybuntu repo visible
4. **Webhook delivery**: GitHub shows successful deliveries
5. **Pipeline runs**: Push triggers CI pipeline

## See Also

- [Troubleshooting Woodpecker CI](../troubleshooting/woodpecker-ci.md)
- [Playbook Reference](../reference/playbooks.md)
