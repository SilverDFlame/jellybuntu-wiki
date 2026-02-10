# Proxmox API User Permissions Documentation

## Overview

This document explains the permissions granted to the `ansible@pve` user and why each permission is required for Ansible
and OpenTofu/Terraform automation in the Jellybuntu homelab project.

**Updated**: 2025 - Expanded to support OpenTofu/Terraform provider requirements

## Security Benefits

- **Principle of Least Privilege**: User has only the minimum permissions needed for automation tasks
- **Limited Blast Radius**: If credentials are compromised, attacker cannot:
  - Access other Proxmox users or authentication settings
  - Modify Proxmox host system configuration
  - Access storage backends directly (only through VM operations)
  - Modify networking or firewall rules on the host
- **Audit Trail**: All API operations are logged separately from root user actions
- **Easy Revocation**: Can disable ansible@pve without affecting other operations

## Permission Breakdown

### VM Operations

| Permission | Why Needed | Used In |
|------------|------------|---------|
| `VM.Allocate` | Create new VMs | Ansible Playbook 01, OpenTofu VM provisioning |
| `VM.Clone` | Clone VMs from cloud-init template | Ansible Playbook 01, OpenTofu VM creation from template |
| `VM.Config.Disk` | Configure VM disk size and storage | Ansible/OpenTofu: Disk resizing, additional disk configuration |
| `VM.Config.CPU` | Configure CPU cores, pinning, limits | Ansible/OpenTofu: CPU allocation, pinning for game servers |
| `VM.Config.Memory` | Configure RAM allocation | Ansible/OpenTofu: Memory allocation per VM |
| `VM.Config.Network` | Configure network interfaces | Ansible/OpenTofu: Static IP assignment, bridge configuration |
| `VM.Config.Options` | Configure general VM options | Ansible/OpenTofu: Cloud-init settings, boot order |
| `VM.Config.CDROM` | Attach ISO images | Ansible/OpenTofu: ISO attachments for installations |
| `VM.Config.Cloudinit` | Configure cloud-init settings | OpenTofu: Cloud-init user data, network config |
| `VM.Config.HWType` | Modify hardware types (SCSI controller, etc.) | OpenTofu: Hardware configuration updates |
| `VM.PowerMgmt` | Start, stop, restart VMs | Power management, maintenance operations |
| `VM.Audit` | View VM configuration and status | All tools: checking VM state |
| `VM.Console` | Access VM console (if needed) | Debugging and troubleshooting |
| `VM.Backup` | Create VM backups | Future: Automated backup operations |
| `VM.Snapshot` | Create VM snapshots | Future: Pre-update snapshots, rollback points |
| `VM.Snapshot.Rollback` | Restore from snapshots | Future: Rollback operations |
| `VM.Migrate` | Migrate VMs between nodes | Future: Multi-node cluster operations |
| `VM.Replicate` | Replicate VMs | Future: High availability configurations |

### Guest Agent Permissions

| Permission | Why Needed | Used In |
|------------|------------|---------|
| `VM.GuestAgent.Audit` | Query guest agent information | OpenTofu: Read network info, eliminate 403 warnings |
| `VM.GuestAgent.FileRead` | Read files via guest agent | Future: Configuration validation |
| `VM.GuestAgent.FileWrite` | Write files via guest agent | Future: Dynamic configuration updates |
| `VM.GuestAgent.FileSystemMgmt` | Manage filesystem via guest agent | Future: Filesystem operations |
| `VM.GuestAgent.Unrestricted` | Full guest agent access | Future: Advanced guest operations |

### Storage Operations

| Permission | Why Needed | Used In |
|------------|------------|---------|
| `Datastore.Allocate` | Allocate and manage datastore resources (delete volumes) | Packer: Cleanup cloud-init volumes after template creation |
| `Datastore.AllocateSpace` | Allocate disk space for VMs | Playbook 01: Creating VM disks |
| `Datastore.Audit` | View storage pool status | All playbooks: checking available space |
| `Datastore.AllocateTemplate` | Store cloud-init templates | Playbook 01: Creating Ubuntu cloud-init template |

### Resource Pool Permissions

| Permission | Why Needed | Used In |
|------------|------------|---------|
| `Pool.Audit` | View resource pools | Future: VM organization in pools |
| `Pool.Allocate` | Create and manage resource pools | OpenTofu: Organizing VMs into pools |

### System Permissions

| Permission | Why Needed | Used In |
|------------|------------|---------|
| `Sys.Audit` | View system information | All tools: Checking node status, available resources |
| `Sys.Modify` | Modify system settings (VM boot order) | Ansible Playbook 01, 15: Setting VM startup order |
| `SDN.Use` | Use software-defined networking | If using Proxmox SDN features |

## Permissions NOT Granted

The ansible@pve user explicitly does NOT have:

- **User Management**: Cannot create, modify, or delete users
- **Host System Access**: Cannot modify Proxmox host configuration
- **Storage Backend**: Cannot modify storage pool configurations
- **Networking**: Cannot modify host network settings or firewall
- **Cluster**: Cannot modify cluster configuration
- **Permissions**: Cannot grant or revoke permissions
- **Backup**: Limited backup/restore operations (not required for this project)

## Role Assignment

```bash
# Role is assigned at datacenter level (/)
pveum aclmod / -user ansible@pve -role Ansible
```

This gives the user access to:

- All VMs in the datacenter
- All storage pools
- All network configurations
- But only for operations permitted by the Ansible role

## Testing Permissions

After creating the user, verify permissions:

```bash
# Test VM listing (should work)
pvesh get /cluster/resources --type vm -u ansible@pve

# Test user listing (should fail)
pvesh get /access/users -u ansible@pve
```

## Complete Permission List (Current)

The `Ansible` role currently includes all permissions required for both Ansible and OpenTofu/Terraform operations:

```bash
Datastore.Allocate
Datastore.AllocateSpace
Datastore.AllocateTemplate
Datastore.Audit
Pool.Audit
Pool.Allocate
SDN.Use
Sys.Audit
Sys.Modify
VM.Allocate
VM.Audit
VM.Backup
VM.Clone
VM.Config.CDROM
VM.Config.CPU
VM.Config.Cloudinit
VM.Config.Disk
VM.Config.HWType
VM.Config.Memory
VM.Config.Network
VM.Config.Options
VM.Console
VM.GuestAgent.Audit
VM.GuestAgent.FileRead
VM.GuestAgent.FileSystemMgmt
VM.GuestAgent.FileWrite
VM.GuestAgent.Unrestricted
VM.Migrate
VM.PowerMgmt
VM.Replicate
VM.Snapshot
VM.Snapshot.Rollback
```

This matches the `PVEVMAdmin` built-in role for VM operations, plus necessary datastore and system permissions.

## Updating Permissions

If you need to add permissions later:

```bash
# View current permissions
pveum role list | grep "^Ansible" -A 20

# Modify the role (requires setting ALL permissions again)
pveum role modify Ansible -privs "Perm1,Perm2,Perm3,..."

# Note: pveum role modify REPLACES all permissions, it doesn't add/remove individually
```

**Important**: Unlike ACL modification, role modification replaces the entire permission set. You must specify all
permissions you want to keep.

## Migration from root@pam

To switch from root@pam to ansible@pve:

1. **Create the user**: Run `./bin/bootstrap/create-proxmox-api-user.sh`

2. **Update secrets file**:

   ```bash
   sops group_vars/all.sops.yaml
   ```

   Change:

   ```yaml
   proxmox_api_user: "root@pam"
   vault_proxmox_password: "<root_password>"
   ```

   To:

   ```yaml
   proxmox_api_user: "ansible@pve"
   vault_proxmox_password: "<ansible_password>"
   ```

3. **Update vars.yml**:

   ```yaml
   proxmox_api_user: "ansible@pve"
   ```

4. **Test connectivity**:

   ```bash
   ansible proxmox_hosts -m ping
   ```

5. **Run a playbook test**:

   ```bash
   ./bin/runtime/ansible-run.sh playbooks/infrastructure/provision-vms.yml --check
   ```

## Security Best Practices

1. **Strong Password**: Use a strong, unique password for ansible@pve
2. **SOPS Storage**: Always store the password in SOPS-encrypted secrets file
3. **Regular Rotation**: Consider rotating the password periodically
4. **Audit Logs**: Review Proxmox logs regularly for unexpected API calls
5. **Backup Credentials**: Keep encrypted backup of secrets file and age key
6. **Emergency Access**: Keep root@pam credentials separate for emergencies

## Troubleshooting

### Permission Denied Errors

If you see "Permission denied" errors:

1. Check which permission is missing:

   ```bash
   # View detailed error in Proxmox logs
   ssh root@proxmox.host
   tail -f /var/log/pve/tasks/active
   ```

2. Add the missing permission:

   ```bash
   pveum role modify Ansible -privs "+Missing.Permission"
   ```

3. Test the operation again

### User Locked Out

If the ansible@pve user is locked:

```bash
# SSH as root
ssh root@proxmox.host

# Check user status
pveum user list | grep ansible

# Reset password
pveum passwd ansible@pve
```

## OpenTofu/Terraform Specific Notes

### Why These Additional Permissions Are Required

When using the `bpg/proxmox` provider for OpenTofu/Terraform:

1. **VM.Config.HWType**: Required to modify hardware configurations like SCSI controller types, which OpenTofu may

   change during updates

2. **VM.Config.Cloudinit**: Essential for managing cloud-init configurations via IaC
3. **VM.GuestAgent.***: Allows OpenTofu to query VM network information and eliminates 403 permission warnings
4. **Pool.Allocate**: Enables organizing VMs into resource pools via code
5. **VM.Backup/Snapshot/Migrate**: Future-proofing for advanced IaC workflows

### Provider Limitations

Note that some Proxmox API operations require `root@pam` access and will fail with API tokens or limited users:

- Setting privileged container feature flags
- Configuring certain low-level hardware settings
- Some hardware mapping operations

For these operations, you may need to use password-based authentication with appropriate permissions or fall back to `root@pam`.

## References

- [Proxmox VE User Management](https://pve.proxmox.com/pve-docs/chapter-pveum.html)
- [Proxmox VE Permissions](https://pve.proxmox.com/wiki/User_Management)
- [Proxmox VE API Documentation](https://pve.proxmox.com/pve-docs/api-viewer/)
- [BPG Proxmox Terraform Provider](https://registry.terraform.io/providers/bpg/proxmox/latest/docs)
