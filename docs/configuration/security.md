# Security Configuration

Comprehensive security guide covering authentication, encryption, access control, and best practices.

## Overview

Security in Jellybuntu follows defense-in-depth principles with multiple layers:

1. **Authentication**: SSH keys, API tokens, encrypted vault
2. **Network**: Tailscale VPN, UFW firewall
3. **Access Control**: Principle of least privilege
4. **Encryption**: Data at rest and in transit
5. **Updates**: Automated security patches

## SSH Key Management

### Architecture Overview

SSH keys are managed from a **single source of truth** in [`group_vars/all.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.yml):

```text
group_vars/all.yml (single definition)
        │
        ├─► ssh_authorized_keys role ─► Proxmox host (all keys)
        │                            ─► All VMs (all keys)
        │
        └─► Packer user-data template ─► Golden image (CI key only)
```

**Key Types**:

| Key | Comment Format | Purpose | Storage |
|-----|----------------|---------|---------|
| Personal (CachyOS) | `Ansible User - CachyOS` | Manual SSH, local Ansible from primary workstation | `~/.ssh/ansible_homelab` |
| Personal (Mac) | `Ansible User - Mac` | Remote development from Mac workstation | `~/.ssh/ansible_homelab` (on Mac) |
| CI | `CI Automation - Woodpecker` | Woodpecker CI pipelines | Woodpecker secret |

### Key Definitions

All public keys are defined in [`group_vars/all.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.yml):

```yaml
# SSH Authorized Keys - Single source of truth for PUBLIC keys
# Comment format: "<Use Case> - <System>"
ssh_authorized_keys:
  - key: "ssh-ed25519 AAAA..."
    comment: "Ansible User - CachyOS"
  - key: "ssh-ed25519 AAAA..."
    comment: "CI Automation - Woodpecker"
```

**Note**: These are public keys (not sensitive). Private keys are stored separately:

- Personal key: `~/.ssh/ansible_homelab` (workstation)
- CI key: Woodpecker secret `ssh_ci_private_key` + Bitwarden backup

### Generating SSH Keys

**Personal key** (during `setup.sh`):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/ansible_homelab -C "Ansible User - CachyOS"
```

**CI key** (one-time setup):

```bash
ssh-keygen -t ed25519 -f ~/.ssh/ansible_ci -C "CI Automation - Woodpecker"
# Add public key to group_vars/all.yml
# Add private key to Woodpecker secret: ssh_ci_private_key
# Backup private key to Bitwarden
```

### Key Distribution

Use [`playbooks/core/00-configure-ssh-keys.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/core/00-configure-ssh-keys.yml) for all SSH key management:

```bash
# Deploy to all hosts (Proxmox + all VMs)
./bin/runtime/ansible-run.sh playbooks/core/00-configure-ssh-keys.yml

# Deploy to Proxmox only
./bin/runtime/ansible-run.sh playbooks/core/00-configure-ssh-keys.yml --tags proxmox

# Deploy to VMs only
./bin/runtime/ansible-run.sh playbooks/core/00-configure-ssh-keys.yml --tags vms

# Deploy to specific hosts
./bin/runtime/ansible-run.sh playbooks/core/00-configure-ssh-keys.yml --limit jellyfin,media-services
```

**Golden image** (CI key only):

```bash
# Local generation (uses Ansible)
./bin/runtime/ansible-run.sh playbooks/utility/generate-packer-userdata.yml

# CI generation (uses Python script)
mise run packer:generate-userdata
```

### SSH Security Best Practices

✅ **Implemented**:

- Key-based authentication only
- ED25519 keys (strong cryptography)
- SSH restricted to Tailscale network (after Phase 4)
- No password authentication
- Separate CI key with minimal privileges
- Golden image contains only CI key (minimal attack surface)
- `exclusive: true` removes unauthorized keys automatically

✅ **Additional Recommendations**:

```bash
# Set proper permissions
chmod 600 ~/.ssh/ansible_homelab
chmod 644 ~/.ssh/ansible_homelab.pub

# Use SSH agent for convenience
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/ansible_homelab
```

### Adding New SSH Keys

1. Add key entry to [`group_vars/all.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.yml):

   ```yaml
   ssh_authorized_keys:
     - key: "ssh-ed25519 AAAA..."
       comment: "New Key - System Name"
   ```

2. Deploy to all hosts:

   ```bash
   ./bin/runtime/ansible-run.sh playbooks/core/00-configure-ssh-keys.yml
   ```

3. If key should be in golden image (CI keys only), regenerate user-data and rebuild:

   ```bash
   mise run packer:generate-userdata
   # Then trigger Packer build
   ```

### Rotating SSH Keys

**Personal key rotation**:

```bash
# 1. Generate new key
ssh-keygen -t ed25519 -f ~/.ssh/ansible_homelab_new -C "Ansible User - CachyOS"

# 2. Update group_vars/all.yml with new public key

# 3. Deploy to all hosts (adds new key, removes old due to exclusive: true)
./bin/runtime/ansible-run.sh playbooks/core/00-configure-ssh-keys.yml

# 4. Verify new key works
ssh -i ~/.ssh/ansible_homelab_new ansible@media-services.discus-moth.ts.net

# 5. Replace local key file
mv ~/.ssh/ansible_homelab_new ~/.ssh/ansible_homelab
mv ~/.ssh/ansible_homelab_new.pub ~/.ssh/ansible_homelab.pub
```

**CI key rotation**:

```bash
# 1. Generate new CI key
ssh-keygen -t ed25519 -f ~/.ssh/ansible_ci_new -C "CI Automation - Woodpecker"

# 2. Update group_vars/all.yml with new public key

# 3. Add new private key to Woodpecker secret (ssh_ci_private_key)

# 4. Deploy to all hosts
./bin/runtime/ansible-run.sh playbooks/core/00-configure-ssh-keys.yml

# 5. Regenerate golden image user-data and rebuild
mise run packer:generate-userdata
# Trigger Packer build (manual or tag)

# 6. Update Bitwarden backup with new private key
```

### Verification

```bash
# Check key exists
ls -la ~/.ssh/ansible_homelab*

# View defined keys
grep -A 10 "ssh_authorized_keys:" group_vars/all.yml

# Test SSH connection
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net

# View authorized keys on VM
ssh -i ~/.ssh/ansible_homelab ansible@media-services.discus-moth.ts.net cat ~/.ssh/authorized_keys
```

## Secrets Management (SOPS + age)

### Purpose

SOPS encrypts sensitive data with age encryption:

- Proxmox API password
- Tailscale API key
- Media services credentials
- Service API keys (Sonarr, Radarr)
- NFS UID/GID

### How It Works

1. Secrets stored in [`group_vars/all.sops.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.sops.yaml) (encrypted with age)
2. Age private key: `~/.config/sops/age/keys.txt`
3. Public key configured in `.sops.yaml`
4. Ansible automatically decrypts during playbook execution
5. No password prompts needed

### Secrets File Creation

Created during `setup.sh`:

```bash
./bin/bootstrap/setup.sh
```

**Contents** (encrypted with SOPS):

```yaml
# Proxmox API
vault_proxmox_password: "..."

# Tailscale
vault_tailscale_api_key: "tskey-api-..."

# Media Services (set during setup.sh)
vault_services_admin_username: "admin"
vault_services_admin_password: "..."

# NFS
vault_nfs_uid: 3000
vault_nfs_gid: 3000

# Service APIs (added post-deployment)
vault_sonarr_api_key: "..."
vault_radarr_api_key: "..."
```

### SOPS Operations

**Edit secrets**:

```bash
sops group_vars/all.sops.yaml
```

**View secrets** (decrypted):

```bash
sops -d group_vars/all.sops.yaml
```

**Re-encrypt after manual edit**:

```bash
sops -e -i group_vars/all.sops.yaml
```

**Verify encryption**:

```bash
# File should show encrypted data
cat group_vars/all.sops.yaml
```

### Age Key Management

**Key locations**:

- Private key: `~/.config/sops/age/keys.txt`
- Public key: Extracted from private key file
- SOPS config: `.sops.yaml` (contains public key)

**View public key**:

```bash
grep "# public key:" ~/.config/sops/age/keys.txt
```

**Backup your key** ⚠️ **Critical**:

```bash
# Without this key, you CANNOT decrypt secrets!
cp ~/.config/sops/age/keys.txt ~/secure-backup/age-key-jellybuntu.txt
```

**Key file permissions**:

```bash
chmod 600 ~/.config/sops/age/keys.txt
```

### Rotating Age Keys

If keys need rotation:

```bash
# 1. Generate new age key
age-keygen -o ~/.config/sops/age/keys-new.txt

# 2. Extract new public key
grep "# public key:" ~/.config/sops/age/keys-new.txt

# 3. Update .sops.yaml with new public key
# Edit .sops.yaml and replace the age: value

# 4. Re-encrypt all secrets with new key
sops updatekeys group_vars/all.sops.yaml

# 5. Replace old key (after verifying decryption works)
mv ~/.config/sops/age/keys-new.txt ~/.config/sops/age/keys.txt

# 6. Test decryption
sops -d group_vars/all.sops.yaml
```

### SOPS Security Best Practices

✅ **Best Practices**:

- Back up age key to secure location (external drive, password manager)
- Never commit age private key to git (`.gitignore` configured)
- Keep age key file permissions at 600
- Encrypt files before committing to git
- Use separate age keys for different environments (dev/prod)
- Rotate age keys annually or after compromise
- Store encrypted files in git (safe to commit)
- Never commit decrypted secrets

## Proxmox API Authentication

### API User Creation

Created via `./create-proxmox-api-user.sh`:

**User**: `ansible@pve`
**Realm**: Proxmox VE (pve)
**Type**: API token for automation

### API Permissions

Minimal permissions following least privilege:

**VM Management**:

- `VM.Allocate` - Create VMs
- `VM.Config.Disk` - Configure disks
- `VM.Config.CPU` - Configure CPU
- `VM.Config.Memory` - Configure RAM
- `VM.Config.Network` - Configure network
- `VM.Config.Options` - General options
- `VM.PowerMgmt` - Start/stop/reboot

**Storage**:

- `Datastore.Allocate` - Use storage
- `Datastore.AllocateSpace` - Allocate disk space

**Networking**:

- `SDN.Use` - Use network resources

See [reference/proxmox-api-permissions.md](../reference/proxmox-api-permissions.md) for complete list.

### API Security

✅ **Security Features**:

- Dedicated API user (not root)
- Minimal required permissions
- Password stored in encrypted vault
- Separate from root@pam credentials

**Verification**:

```bash
# Test API authentication
ansible proxmox_hosts -m ping
```

### API Token Alternative

For even more security, use API tokens instead of passwords:

**Create token**:

```bash
ssh root@jellybuntu.discus-moth.ts.net
pveum user token add ansible@pve ansible-token --privsep=0
```

**Configure in vault**:

```yaml
vault_proxmox_api_token_id: "ansible@pve!ansible-token"
vault_proxmox_api_token_secret: "..."
```

## Service Authentication

### Media Services Credentials

**Unified Authentication**: All services use same credentials

- qBittorrent
- SABnzbd
- Sonarr
- Radarr
- Prowlarr
- Jellyseerr

**Configuration**:
Set during `setup.sh` in [`group_vars/all.sops.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.sops.yaml):

```yaml
vault_services_admin_username: "admin"
vault_services_admin_password: "..."
```

**Auto-Configuration**:

- qBittorrent password set via Web API (Phase 3)
- Other services require manual configuration

### API Keys

**Purpose**: Service-to-service authentication

**Sonarr/Radarr API Keys**:
Generated automatically by services, retrieved manually:

```bash
# Access service web UI
# Settings → General → Security → API Key
```

**Adding to Secrets**:

```bash
sops group_vars/all.sops.yaml

# Add:
vault_sonarr_api_key: "..."
vault_radarr_api_key: "..."
```

**Usage**:

- Recyclarr: Syncs custom formats
- Prowlarr: Adds indexers to services
- Jellyseerr: Requests media

### Jellyfin Authentication

**Initial Setup**: Create admin account on first access
**Recommendation**: Use strong password, different from services

**Additional Security**:

- Enable HTTPS (optional, via reverse proxy)
- Restrict library access per user
- Enable two-factor authentication (if needed)

## Firewall Configuration (UFW)

### Firewall Philosophy

**Default Policy**: Deny all, allow specific

**SSH Access**:

- ✅ Tailscale network (100.64.0.0/10)
- ❌ Direct IP access
- ❌ Public internet

**Service Ports**:

- ✅ Local network (192.168.0.0/24)
- ✅ Tailscale network
- ❌ Public internet (except game servers)

### Firewall Deployment

Enabled during Phase 4:

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase4-post-deployment.yml
```

**What Happens**:

1. UFW installed on all VMs
2. Rules configured from [`host_vars/<vm>.yml`](https://github.com/SilverDFlame/jellybuntu/tree/main/host_vars)
3. Default policy set to deny
4. SSH restricted to Tailscale
5. Firewall enabled

### Firewall Management

**View rules**:

```bash
sudo ufw status verbose
```

**Add rule**:

```bash
sudo ufw allow from 192.168.0.0/24 to any port 8080 proto tcp
```

**Delete rule**:

```bash
sudo ufw status numbered
sudo ufw delete <number>
```

**Disable** (emergency):

```bash
sudo ufw disable
```

**Enable**:

```bash
sudo ufw enable
```

See [networking.md](networking.md) for detailed firewall rules per VM.

## Tailscale VPN Security

### Encryption

**Protocol**: WireGuard
**Encryption**: ChaCha20-Poly1305
**Key Exchange**: Noise protocol framework

**Security Features**:

- End-to-end encrypted
- Perfect forward secrecy
- Automatic key rotation
- No configuration needed

### Authentication

**Ephemeral Keys**: VMs use ephemeral auth keys that:

- Expire when VM is destroyed
- Don't require manual deauthorization
- Reduce security risk from lost VMs

**API Key Generation**:

```yaml
# In group_vars/all.sops.yaml
vault_tailscale_api_key: "tskey-api-..."
```

**Key Permissions**:

- Reusable: Can be used multiple times
- Ephemeral: Nodes disappear when offline
- Expiration: Set to 90+ days

### Access Control

**Current**: All devices in same Tailscale network

**Future ACLs**: Fine-grained control possible

Example ACL:

```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["tag:homelab"],
      "dst": ["tag:homelab:*"]
    }
  ],
  "tagOwners": {
    "tag:homelab": ["user@example.com"]
  }
}
```

See [reference/tailscale-auto-approval.md](../reference/tailscale-auto-approval.md).

## Unattended Upgrades

### Purpose

Automatic security updates keep systems patched without manual intervention.

### Configuration

Enabled during Phase 4:

```bash
./bin/runtime/ansible-run.sh playbooks/phases/phase4-post-deployment.yml
```

**What Gets Updated**:

- Security updates (high priority)
- Critical bug fixes
- Ubuntu base packages

**What Doesn't**:

- Major version upgrades
- Kernel updates (requires reboot)
- Third-party repositories

### Settings

**Auto-Reboot**: Disabled by default (prevents unexpected downtime)

**Update Frequency**: Daily check, install when available

**Configuration File**: `/etc/apt/apt.conf.d/50unattended-upgrades`

### Management

**Check status**:

```bash
systemctl status unattended-upgrades
```

**View logs**:

```bash
sudo cat /var/log/unattended-upgrades/unattended-upgrades.log
```

**Manual trigger**:

```bash
sudo unattended-upgrade --debug
```

**Disable** (if needed):

```bash
sudo systemctl stop unattended-upgrades
sudo systemctl disable unattended-upgrades
```

## Security Checklist

### ✅ Authentication

- [ ] SSH keys generated and distributed
- [ ] Password authentication disabled
- [ ] Vault encrypted with strong password
- [ ] Proxmox API user created with minimal permissions
- [ ] Service credentials set and secured

### ✅ Network Security

- [ ] UFW firewall enabled on all VMs
- [ ] SSH restricted to Tailscale network
- [ ] Service ports limited to local + Tailscale
- [ ] Tailscale VPN active on all VMs

### ✅ Access Control

- [ ] Principle of least privilege applied
- [ ] Separate credentials for different services
- [ ] API keys not committed to git
- [ ] Vault password not stored in plaintext

### ✅ Updates

- [ ] Unattended upgrades configured
- [ ] Security patches applied automatically
- [ ] System up to date

### ⚠️ Consider Implementing

- [ ] Fail2ban for brute force protection
- [ ] Reverse proxy with HTTPS
- [ ] Regular security audits
- [ ] Backup encryption
- [ ] Intrusion detection (optional)

## Incident Response

### Compromised SSH Key

**Actions**:

1. Generate new SSH key immediately
2. Update [`group_vars/all.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.yml) with new public key (remove old)
3. Deploy to all hosts using SSH key playbook
4. Regenerate golden image if CI key compromised
5. Review access logs for unauthorized access
6. Consider rotating all credentials

**Commands**:

```bash
# Check SSH logs
sudo journalctl -u sshd -n 100

# Remove old key from known_hosts
ssh-keygen -R hostname

# Deploy new keys to all hosts (removes old keys due to exclusive: true)
./bin/runtime/ansible-run.sh playbooks/core/00-configure-ssh-keys.yml

# If CI key compromised, regenerate golden image
mise run packer:generate-userdata
# Trigger Packer build
```

### Compromised Age Key

**Actions**:

1. Generate new age key immediately
2. Re-encrypt all secrets with new key
3. Review git history for exposures
4. Rotate all credentials in secrets file
5. Update all service passwords
6. Regenerate API keys

**Commands**:

```bash
# Generate new age key
age-keygen -o ~/.config/sops/age/keys-new.txt

# Extract public key and update .sops.yaml
grep "# public key:" ~/.config/sops/age/keys-new.txt

# Re-encrypt secrets with new key
sops updatekeys group_vars/all.sops.yaml

# Replace old key
mv ~/.config/sops/age/keys-new.txt ~/.config/sops/age/keys.txt

# Update service passwords
# Manually in each service web UI
```

### Compromised Service Account

**Actions**:

1. Change service password in secrets file (`sops group_vars/all.sops.yaml`)
2. Re-run deployment to update services
3. Review service logs for unauthorized activity
4. Regenerate API keys if exposed

### Unauthorized Access Detected

**Actions**:

1. Identify entry point
2. Disable compromised credentials
3. Review firewall logs
4. Check for malware/backdoors
5. Restore from backup if needed
6. Implement additional controls

## Security Resources

### Internal Documentation

- [Networking Configuration](networking.md) - Firewall and VPN
- [Proxmox API Permissions](../reference/proxmox-api-permissions.md) - API security
- [Tailscale Auto-Approval](../reference/tailscale-auto-approval.md) - VPN ACLs

### External Resources

- [SOPS Documentation](https://github.com/getsops/sops)
- [age Encryption](https://age-encryption.org/)
- [Tailscale Security](https://tailscale.com/security/)
- [UFW Ubuntu Guide](https://help.ubuntu.com/community/UFW)
- [SSH Hardening Guide](https://www.ssh.com/academy/ssh/hardening)

## Summary

**Authentication**:

- SSH keys for automation
- SOPS + age encryption for secrets
- Dedicated Proxmox API user
- Unified service credentials

**Network Security**:

- Tailscale VPN (WireGuard encryption)
- UFW firewall (deny by default)
- SSH via Tailscale + LAN (see design note below)
- Minimal port exposure

> **Design Decision: LAN Fallback for SSH**
>
> SSH is intentionally allowed from both Tailscale (100.64.0.0/10) and the local network
> (192.168.0.0/24). This dual-access pattern provides resilience during Tailscale outages
> or authentication failures. Without LAN fallback, a Tailscale service disruption would
> completely lock out administrators from their own infrastructure. The security trade-off
> is acceptable because the local network is already a trusted zone behind a home router.

**Access Control**:

- Principle of least privilege
- Role-based permissions
- API key separation
- Audit logging

**Maintenance**:

- Automated security updates
- Regular credential rotation
- Incident response procedures
- Security monitoring

Your homelab follows security best practices for authentication, encryption, and access control!
