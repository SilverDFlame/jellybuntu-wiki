# Modular Architecture Migration

## Overview

The codebase has been refactored into a modular, role-based architecture following Ansible best practices.

## Changes Made

### Roles Created (6)

1. **docker** - Docker and Docker Compose installation
2. **tailscale** - Tailscale VPN setup with ephemeral keys
3. **ufw_firewall** - Firewall configuration from host_vars
4. **unattended_upgrades** - Automatic security updates
5. **nfs_client** - NFS client and mount management
6. **docker_compose_app** - Docker Compose application deployment

### Host Variables Created (5)

Variables moved from playbooks to `host_vars/`:

- `home-assistant.yml` - Firewall ports, directories
- `satisfactory-server.yml` - Game server ports
- `jellyfin.yml` - Media server ports, directories
- `media-services.yml` - Service ports, compose config
- `download-clients.yml` - Download client ports, compose config

### Role-Based Playbooks (5)

New playbooks using roles (with `-role.yml` suffix):

- `02-configure-tailscale-role.yml`
- `05-configure-media-services-role.yml`
- `06-configure-download-clients-role.yml`
- `11-configure-ufw-firewall-role.yml`
- `12-configure-unattended-upgrades-role.yml`

## Benefits

### Code Reuse

- Docker installation: 2 playbooks → 1 role
- UFW configuration: 500+ lines → 70-line role
- Tailscale setup: Reusable across all VMs

### Maintainability

- Update Docker installation in ONE place
- Change firewall logic without touching playbooks
- Port definitions in host_vars, not hardcoded

### Testing

- Test roles independently
- Verify role behavior across different hosts
- Easier to debug with smaller units

### Flexibility

- Override role defaults with host_vars
- Mix and match roles in playbooks
- Add new hosts by creating host_vars file

### Consistency

- Same installation method across all VMs
- Standardized firewall rules
- Uniform configuration templates

## Usage Examples

### Before (Monolithic)

```yaml
# playbook 05
tasks:
  - name: Install Docker prerequisites
    apt: ...
  - name: Install Docker
    shell: ...
  - name: Add user to docker group
    user: ...
  # 50+ more lines...
```

### After (Modular)

```yaml
# playbook 05-role
roles:
  - docker
  - nfs_client
  - docker_compose_app
```

### Port Configuration

**Before**: Hardcoded in playbook

```yaml
# In playbook 11
vars:
  media_services_ports:
    - { port: 8989, proto: tcp, comment: "Sonarr" }
```

**After**: In host_vars

```yaml
# host_vars/media-services.yml
firewall_ports:
  - { port: 8989, proto: tcp, comment: "Sonarr" }
  - { port: 7878, proto: tcp, comment: "Radarr" }
```

## Migration Path

### For Existing Deployments

1. Original playbooks remain unchanged
2. Role-based playbooks have `-role.yml` suffix
3. Test role-based playbooks in parallel
4. Switch when comfortable

### For New Deployments

Use role-based playbooks from the start:

```bash
ansible-playbook -i ../inventory.ini 05-configure-media-services-role.yml
```

## Backward Compatibility

✅ Original playbooks: Still functional
✅ Existing infrastructure: No changes required
✅ Documentation: Updated to show both approaches
✅ Group variables: Unchanged

## File Locations

```text
roles/
├── docker/tasks/main.yml          # Docker installation logic
├── tailscale/tasks/main.yml       # Tailscale setup logic
├── ufw_firewall/tasks/main.yml    # Firewall rules logic
├── unattended_upgrades/tasks/     # Auto-update logic
│   └── main.yml
├── nfs_client/tasks/main.yml      # NFS mount logic
└── docker_compose_app/tasks/      # Compose deployment logic
    └── main.yml

host_vars/
├── home-assistant.yml             # HA-specific config
├── satisfactory-server.yml        # Game server config
├── jellyfin.yml                   # Media server config
├── media-services.yml             # Services stack config
└── download-clients.yml           # Download clients config

playbooks/
├── 02-configure-tailscale.yml        # Original (legacy)
├── 02-configure-tailscale-role.yml   # Role-based (new)
├── 05-configure-media-services.yml   # Original (legacy)
├── 05-configure-media-services-role.yml  # Role-based (new)
└── ...
```

## Best Practices

### When to Use Roles

- Repeating tasks across playbooks
- Common infrastructure patterns
- Cross-project reusability

### When to Use Host Vars

- Host-specific configuration
- Port definitions
- Directory paths
- Service-specific settings

### When to Use Group Vars

- Network settings (Tailscale, local)
- Global defaults (timezone, NFS server)
- Shared credentials (from vault)

## Next Steps

1. Review role documentation in [`roles/README.md`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/README.md)
2. Test role-based playbooks
3. Add new roles as needed
4. Migrate remaining playbooks gradually

## Documentation

- **Roles**: [`roles/README.md`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/README.md)
- **Architecture**: `docs/architecture.md`
- **Playbooks**: `docs/reference/playbooks.md`
