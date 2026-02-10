# SOPS Age Key Rotation

Procedures for rotating the age encryption key used with SOPS for secrets management.

## Overview

SOPS uses age encryption to protect sensitive data in [`group_vars/all.sops.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.sops.yaml). Key rotation should be performed:

- **Scheduled**: Annually as a security best practice
- **Emergency**: Immediately if key compromise is suspected

## Prerequisites

- Access to current age private key (`~/.config/sops/age/keys.txt`)
- Backup of current key stored securely (Bitwarden, external drive)
- `age` and `sops` commands installed

```bash
# Verify tools are installed
age --version
sops --version
```

## Scheduled Key Rotation

### Step 1: Generate New Age Key

```bash
# Generate new key pair
age-keygen -o ~/.config/sops/age/keys-new.txt

# Extract the public key (needed for .sops.yaml)
grep "# public key:" ~/.config/sops/age/keys-new.txt
```

**Example output:**

```text
# created: 2025-12-17T12:00:00Z
# public key: age1abc123...xyz789
AGE-SECRET-KEY-1XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### Step 2: Update SOPS Configuration

Edit `.sops.yaml` to add the new public key:

```yaml
creation_rules:
  - path_regex: group_vars/.*\.sops\.ya?ml$
    age: >-
      age1abc123...xyz789
```

Replace the existing `age:` value with the new public key from Step 1.

### Step 3: Re-encrypt Secrets with New Key

```bash
# Update keys in the encrypted file
sops updatekeys group_vars/all.sops.yaml

# Verify by decrypting (requires NEW key)
sops -d group_vars/all.sops.yaml
```

The `updatekeys` command re-encrypts the data key with the new age public key while preserving the content.

### Step 4: Test Decryption

```bash
# Temporarily use new key
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys-new.txt

# Test decryption
sops -d group_vars/all.sops.yaml | head -10

# Run Ansible to verify it works
./bin/runtime/ansible-run.sh --check playbooks/system/ssh-keys.yml
```

### Step 5: Replace Old Key

Once verified, replace the old key:

```bash
# Backup old key (in case of issues)
cp ~/.config/sops/age/keys.txt ~/.config/sops/age/keys-old.txt

# Replace with new key
mv ~/.config/sops/age/keys-new.txt ~/.config/sops/age/keys.txt

# Set proper permissions
chmod 600 ~/.config/sops/age/keys.txt

# Remove old key (keep backup externally)
rm ~/.config/sops/age/keys-old.txt
```

### Step 6: Update Secure Backup

Store the new private key in your secure backup location:

- Bitwarden/1Password secure note
- Encrypted external drive
- Hardware security module (enterprise)

**Never commit the private key to git.**

### Step 7: Commit Configuration Changes

```bash
git add .sops.yaml
git commit -m "chore: Rotate SOPS age key (annual rotation)"
git push
```

## Emergency Key Rotation (Compromise Response)

If the age private key is potentially compromised:

### Immediate Actions

1. **Assume all secrets are exposed** - the age key decrypts everything in `all.sops.yaml`
2. **Follow the scheduled rotation steps above** (Steps 1-6)
3. **Rotate ALL secrets in the vault** (Step 8 below)
4. **Audit git history** for any accidental commits of the private key

### Step 8: Rotate All Secrets

After rotating the age key, rotate all secrets stored in the vault:

```bash
sops group_vars/all.sops.yaml
```

Change the following:

```yaml
# Proxmox API - Change password in Proxmox first, then update here
vault_proxmox_password: "new_secure_password"

# Tailscale - Generate new API key in Tailscale admin console
vault_tailscale_api_key: "tskey-api-NEW..."

# Media Services - Change in each service's web UI
vault_services_admin_password: "new_secure_password"

# Service API Keys - Regenerate in each service
vault_sonarr_api_key: "regenerated_key"
vault_radarr_api_key: "regenerated_key"
```

### Step 9: Update Services

After changing secrets, redeploy to apply new credentials:

```bash
# Update qBittorrent password
./bin/runtime/ansible-run.sh playbooks/services/download-clients.yml

# Update Recyclarr with new API keys
./bin/runtime/ansible-run.sh playbooks/services/recyclarr.yml
```

### Step 10: Audit and Document

1. Review git history for accidental key commits
2. Check for any unauthorized access in service logs
3. Document the incident and rotation date

## Verification Commands

```bash
# Check current key exists
ls -la ~/.config/sops/age/keys.txt

# View public key from private key
grep "# public key:" ~/.config/sops/age/keys.txt

# Test decryption
sops -d group_vars/all.sops.yaml | head -5

# Verify .sops.yaml matches current key
cat .sops.yaml

# Test Ansible integration
./bin/runtime/ansible-run.sh --check playbooks/system/ssh-keys.yml
```

## Troubleshooting

### Decryption Fails After Rotation

**Symptom:** `Error decrypting key with age`

**Cause:** `.sops.yaml` public key doesn't match the private key in `keys.txt`

**Solution:**

```bash
# Extract public key from private key
grep "# public key:" ~/.config/sops/age/keys.txt

# Update .sops.yaml with correct public key
# Then re-encrypt
sops updatekeys group_vars/all.sops.yaml
```

### Lost Private Key

**Symptom:** Cannot decrypt `all.sops.yaml`

**Prevention:** Always maintain a secure backup

**Recovery:**

1. Restore from secure backup (Bitwarden, external drive)
2. If no backup exists, secrets are lost - recreate from scratch:

   ```bash
   # Delete encrypted file
   rm group_vars/all.sops.yaml

   # Re-run SOPS initialization
   ./bin/bootstrap/lib/05-initialize-sops.sh

   # Manually re-enter all secrets
   ```

### Multiple Recipients

For team environments, you can add multiple age public keys:

```yaml
# .sops.yaml
creation_rules:
  - path_regex: group_vars/.*\.sops\.ya?ml$
    age: >-
      age1user1...,
      age1user2...
```

This allows multiple team members to decrypt with their own keys.

## Related Documentation

- [Security Configuration](../configuration/security.md) - Complete security overview
- [Initial Setup](../deployment/initial-setup.md) - SOPS initialization during bootstrap
- [SOPS Official Docs](https://github.com/getsops/sops)
- [age Encryption](https://age-encryption.org/)
