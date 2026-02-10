# Container Versioning Strategies

This document describes the versioning strategies used for container images in the Jellybuntu infrastructure.

## Overview

Different container image providers use different versioning strategies. Understanding these strategies helps
make informed decisions about when to pin versions and when to use rolling tags.

## LinuxServer.io Images

**Strategy**: Rolling `:latest` tag

LinuxServer.io images (prefixed with `lscr.io/linuxserver/`) use `:latest` as their primary versioning strategy.
They do not publish semantic version tags like `1.2.3`.

### Why `:latest` is Acceptable for LinuxServer

1. **Stable releases only**: LinuxServer only pushes stable upstream releases to `:latest`
2. **Consistent behavior**: Their images follow predictable patterns and rarely introduce breaking changes
3. **No alternative**: Semantic version tags are not published, so pinning isn't possible
4. **Update mechanism**: Updates are handled via container recreation during playbook runs

### Examples

```yaml
# LinuxServer images - :latest is the standard approach
unifi_image: "lscr.io/linuxserver/unifi-network-application:latest"
sonarr_image: "lscr.io/linuxserver/sonarr:latest"
radarr_image: "lscr.io/linuxserver/radarr:latest"
jellyseerr_image: "lscr.io/linuxserver/jellyseerr:latest"
```

### Updating LinuxServer Containers

To update a LinuxServer container:

```bash
# Pull latest image
podman pull lscr.io/linuxserver/sonarr:latest

# Recreate container (via Ansible)
./bin/runtime/ansible-run.sh playbooks/services/media-services.yml
```

## Official/Upstream Images

**Strategy**: Pin to specific patch version

For official images from Docker Hub or other registries, always pin to a specific patch version to prevent
unexpected breaking changes.

### Why Pin Official Images

1. **Predictable deployments**: Same image every time until explicitly updated
2. **Breaking changes**: Major/minor version bumps may introduce incompatibilities
3. **Rollback capability**: Easy to revert by changing the version number
4. **Audit trail**: Version changes are tracked in git

### Examples

```yaml
# Official images - always pin to specific version
mongo_image: "docker.io/library/mongo:7.0.28"
postgres_image: "docker.io/library/postgres:16.2"
redis_image: "docker.io/library/redis:7.2.4"
```

### Updating Pinned Images

1. Check for available versions:

   ```bash
   skopeo list-tags docker://docker.io/library/mongo | jq -r '.Tags[]' | grep -E '^7\.0\.[0-9]+$' | sort -V | tail -5
   ```

2. Update the version in the role's `defaults/main.yml`

3. Run the playbook to deploy the update

## Version Lookup Commands

| Registry | Command |
|----------|---------|
| Docker Hub | `skopeo list-tags docker://docker.io/library/<image>` |
| LinuxServer | `skopeo list-tags docker://lscr.io/linuxserver/<image>` |
| GitHub CR | `skopeo list-tags docker://ghcr.io/<org>/<image>` |
| Quay.io | `skopeo list-tags docker://quay.io/<org>/<image>` |

## Decision Matrix

| Image Source | Versioning Strategy | Example |
|--------------|---------------------|---------|
| LinuxServer.io | Use `:latest` | `lscr.io/linuxserver/sonarr:latest` |
| Official (Docker Hub) | Pin patch version | `docker.io/library/mongo:7.0.28` |
| Third-party | Pin patch version | `ghcr.io/example/app:2.1.3` |
| Development/testing | Use `:latest` or `:dev` | Only in non-production |

## Best Practices

1. **Document the strategy**: Add comments in role defaults explaining versioning choices
2. **Review before updates**: Check release notes before bumping versions
3. **Test updates**: Run playbooks in check mode before applying version changes
4. **Track in git**: Version changes should be committed with clear messages

## See Also

- [Podman App Role](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/podman_app) - Container deployment
- [LinuxServer.io](https://www.linuxserver.io/) - Container image provider
- [Container Resource Management](../configuration/container-resource-management.md)
