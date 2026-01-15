# Nexus Repository Configuration

Configuration guide for Nexus Repository OSS container registry and artifact caching.

## Overview

Nexus Repository provides centralized container image caching and artifact management. All CI/CD pipelines and service
deployments pull container images through Nexus, reducing external dependencies and improving build reliability.

**Location**: NAS VM (192.168.0.15)
**Ports**:

| Port | Purpose | Authentication |
|------|---------|----------------|
| 8081 | Web UI and API | Required |
| 5000 | Docker hosted registry | Required |
| 5001 | Docker group (unified endpoint) | Anonymous allowed |

## Registry Ports Explained

### Port 5000 - Hosted Registry

Used for pushing custom images (e.g., `packer-ansible`). Requires authentication.

```bash
# Login required for push
podman login nas.discus-moth.ts.net:5000

# Push custom image
podman push nas.discus-moth.ts.net:5000/packer-ansible:latest
```

### Port 5001 - Group Endpoint (Recommended for Pulls)

Unified endpoint that searches across all configured repositories:

1. `docker-hosted` (local images)
2. `docker-hub-proxy` (docker.io cache)
3. `docker-ghcr-proxy` (ghcr.io cache)
4. `docker-lscr-proxy` (lscr.io cache)
5. `docker-quay-proxy` (quay.io cache)
6. `docker-gcr-proxy` (gcr.io cache)

```bash
# No login needed for pulls
podman pull nas.discus-moth.ts.net:5001/library/alpine:latest
podman pull nas.discus-moth.ts.net:5001/linuxserver/sonarr:latest
```

### Why Two Ports?

- **Port 5000**: Dedicated hosted registry for custom images, with authentication
- **Port 5001**: Group endpoint combining hosted + all proxy registries, allows anonymous pulls

This separation allows:

- Anonymous pulls from any cached registry (convenient for CI/CD)
- Authenticated pushes only (prevents unauthorized image uploads)

## Security Considerations

### Anonymous Pull Access

Anonymous pulls are enabled on port 5001 for convenience. This means:

- Anyone on the local network can pull images without authentication
- No audit trail for anonymous pulls
- Registry enumeration possible (listing available images)

**Mitigations in place:**

1. UFW firewall restricts port 5001 to local network (192.168.0.0/24) and Tailscale (100.64.0.0/10)
2. Nexus is not exposed to the public internet
3. Push operations still require authentication

### Alternative: Require Authentication

To require authentication for all operations, modify the security realms in [`host_vars/nas.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/nas.yml):

```yaml
nexus_api_config:
  # Change realm order - NexusAuthenticatingRealm first disables anonymous
  # Current: DockerToken first enables anonymous pulls
  # To require auth: Put NexusAuthenticatingRealm first
```

Then update [`roles/podman_app/templates/nexus_api.sh.j2`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/podman_app/templates/nexus_api.sh.j2) to change the realm order.

### DockerToken Realm

The DockerToken realm must be enabled for Docker registry operations. Its position in the realm list determines
anonymous access behavior:

- **First position**: Anonymous pulls allowed (current configuration)
- **After NexusAuthenticatingRealm**: Authentication required for all operations

## Initial Deployment

### Bootstrap Consideration

Nexus cannot pull its own image from itself during initial deployment. The playbook uses `docker.io` directly:

```yaml
# playbooks/core/20-configure-nexus-role.yml
container_image: "docker.io/sonatype/nexus3:3.87.1"  # NOT through Nexus
```

This is intentional and must remain as-is for fresh deployments.

## Repository Configuration

### Docker Repositories

| Repository | Type | Remote URL | Purpose |
|------------|------|------------|---------|
| docker-hosted | hosted | - | Custom images (packer-ansible) |
| docker-hub-proxy | proxy | https://registry-1.docker.io | Docker Hub cache |
| docker-ghcr-proxy | proxy | https://ghcr.io | GitHub Container Registry |
| docker-lscr-proxy | proxy | https://lscr.io | LinuxServer.io |
| docker-quay-proxy | proxy | https://quay.io | Red Hat Quay |
| docker-gcr-proxy | proxy | https://gcr.io | Google Container Registry |
| docker-group | group | - | Unified endpoint (port 5001) |

### APT Repository

| Repository | Type | Remote URL | Purpose |
|------------|------|------------|---------|
| apt-ubuntu-proxy | proxy | http://archive.ubuntu.com/ubuntu | Ubuntu package cache |

Used by Packer golden image builds to cache APT packages.

### PyPI Repository

| Repository | Type | Remote URL | Purpose |
|------------|------|------------|---------|
| pypi-proxy | proxy | https://pypi.org | Python package cache |

Used by MkDocs documentation builds.

## Image References

All playbooks and CI pipelines use the group endpoint (port 5001) for container images:

```yaml
# Format
container_image: "nas.discus-moth.ts.net:5001/<registry>/<image>:<tag>"

# Examples
container_image: "nas.discus-moth.ts.net:5001/linuxserver/sonarr:latest"
container_image: "nas.discus-moth.ts.net:5001/library/alpine:3.21"
container_image: "nas.discus-moth.ts.net:5001/python:3.12-alpine"
```

## Verification

### Test Pull Through Proxy

```bash
# Should pull from Docker Hub via Nexus proxy
podman pull nas.discus-moth.ts.net:5001/library/alpine:latest

# Verify in Nexus UI: Browse > docker-hub-proxy should show cached layers
```

### Check Repository Status

```bash
# API health check
curl -u admin:password http://nas.discus-moth.ts.net:8081/service/rest/v1/status

# List repositories
curl -u admin:password http://nas.discus-moth.ts.net:8081/service/rest/v1/repositories
```

## Troubleshooting

### 403 Forbidden on Pull

1. Verify DockerToken realm is enabled and first in the list
2. Check anonymous access is enabled in Security > Anonymous Access
3. Verify the repository exists in the docker-group members

### Slow First Pull

First pulls are slow because Nexus must fetch from upstream. Subsequent pulls use cached layers.

### Registry Not Accessible

1. Check Nexus container is running: `podman ps`
2. Verify ports are exposed: `ss -tlnp | grep -E '5000|5001|8081'`
3. Check UFW allows the ports: `sudo ufw status`

## See Also

- [Nexus Maintenance](../maintenance/nexus-maintenance.md) - Cleanup policies, disk management, scheduled tasks
- [Playbook 20: Nexus Configuration](../reference/playbooks.md#20-configure-nexus-roleyml)
- [Service Endpoints](service-endpoints.md)
- [Nexus Official Documentation](https://help.sonatype.com/en/docker-registry.html)
