# SSH Bastion Configuration

The NAS VM (192.168.30.15) serves as an SSH bastion/jump host for emergency access when Tailscale is unavailable.

## Why NAS as Bastion?

- **Non-ephemeral Tailscale connection**: Persists across network outages
- **Always-on infrastructure**: First VM to start (startup order 1)
- **Network connectivity**: Direct access to all VMs on 192.168.10.0/24
- **Minimal attack surface**: Storage-only VM with limited services

## Usage

### Manual SSH via Bastion

```bash
# Direct SSH with ProxyJump
ssh -i ~/.ssh/ansible_homelab -o ProxyJump=ansible@192.168.30.15 ansible@192.168.30.12

# Using SSH config (~/.ssh/config)
Host nas-bastion
    HostName 192.168.30.15
    User ansible
    IdentityFile ~/.ssh/ansible_homelab

Host jellyfin-via-bastion
    HostName 192.168.30.12
    User ansible
    IdentityFile ~/.ssh/ansible_homelab
    ProxyJump nas-bastion
```

### Ansible via Bastion

```bash
# Use bastion inventory
ansible -i inventory-bastion.ini <host> -m ping
ansible-playbook -i inventory-bastion.ini playbooks/...

# Examples
ansible -i inventory-bastion.ini jellyfin -m ping
ansible -i inventory-bastion.ini media_stack -m shell -a 'uptime'
```

## Inventory Files

| File | Purpose | Connection Method |
|------|---------|-------------------|
| [`inventory.ini`](https://github.com/SilverDFlame/jellybuntu/blob/main/inventory.ini) | Normal operations | Tailscale hostnames |
| `inventory-bastion.ini` | Emergency access | ProxyJump through NAS (192.168.30.15) |

## Bastion Inventory Structure

All VMs (except NAS itself) use ProxyJump:

```ini
[jellyfin_servers:vars]
ansible_user=ansible
ansible_become=yes
ansible_ssh_common_args='-o ConnectTimeout=5 -o ProxyJump=ansible@192.168.30.15'
```

NAS has direct connection (no jump):

```ini
[nas_servers:vars]
ansible_user=ansible
ansible_become=yes
ansible_ssh_common_args='-o ConnectTimeout=5'
```

> **Note**: Before first connection, populate your `~/.ssh/known_hosts` with host keys:
>
> ```bash
> ssh-keyscan -H 192.168.30.15 >> ~/.ssh/known_hosts
> ssh-keyscan -H 192.168.30.12 >> ~/.ssh/known_hosts
> # Repeat for other VMs as needed
> ```

## When to Use Bastion Access

Use `inventory-bastion.ini` when:

- Tailscale is down or DNS not resolving
- SSH keys changed and need to re-accept host keys
- Debugging network connectivity issues
- Emergency maintenance when Tailscale unavailable

## Security Considerations

- **NAS must be accessible**: Bastion requires you can reach 192.168.30.15
- **SSH key required**: Same key used for all VMs (`~/.ssh/ansible_homelab`)
- **No password authentication**: Key-based authentication only
- **Firewall rules**: NAS allows SSH from local network + Tailscale

## Troubleshooting

### Cannot reach bastion (192.168.30.15)

```bash
# Verify NAS is reachable
ping 192.168.30.15
ssh -i ~/.ssh/ansible_homelab ansible@192.168.30.15

# Check Tailscale status on NAS
ssh -i ~/.ssh/ansible_homelab ansible@192.168.30.15 "tailscale status"
```

### ProxyJump fails

```bash
# Test with verbose output
ssh -v -o ProxyJump=ansible@192.168.30.15 ansible@192.168.30.12

# Verify NAS can reach target
ssh -i ~/.ssh/ansible_homelab ansible@192.168.30.15 "ping -c 1 192.168.30.12"
```

### Host key verification failed

```bash
# Clear old host key and re-scan
ssh-keygen -R 192.168.30.12
ssh-keyscan -H 192.168.30.12 >> ~/.ssh/known_hosts

# Then connect normally
ssh -o ProxyJump=ansible@192.168.30.15 ansible@192.168.30.12
```

> **Security Warning**: Avoid using `StrictHostKeyChecking=no` as it disables MITM attack protection.
> Always verify host keys have changed legitimately (e.g., after VM rebuild) before clearing them.

## Related Documentation

- [Tailscale Configuration](./tailscale-auto-approval.md)
- [Networking Architecture](../configuration/networking.md)
- [NAS Setup](./nas-setup.md)
