# OpenTofu State Encryption Key Rotation

Procedures for rotating the passphrase used to encrypt OpenTofu state files.

## Overview

OpenTofu state encryption protects sensitive infrastructure data using AES-256-GCM with PBKDF2 key
derivation. The passphrase is stored in the SOPS-encrypted vault and should be rotated:

- **Scheduled**: Annually as a security best practice
- **Emergency**: Immediately if passphrase compromise is suspected

## How State Encryption Works

```hcl
# infrastructure/terraform/main.tf
encryption {
  key_provider "pbkdf2" "state_encryption" {
    passphrase = var.state_encryption_passphrase
  }

  method "aes_gcm" "default" {
    keys = key_provider.pbkdf2.state_encryption
  }

  state {
    method   = method.aes_gcm.default
    enforced = true
  }
}
```

- **Passphrase**: Stored in `vault_state_encryption_passphrase` (SOPS vault)
- **Key Derivation**: PBKDF2 derives AES-256 key from passphrase
- **Encryption**: AES-256-GCM encrypts state data
- **Location**: [`infrastructure/terraform/.env`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/.env) sources passphrase from vault

## Prerequisites

- Access to SOPS vault (`~/.config/sops/age/keys.txt`)
- Current state encryption passphrase
- OpenTofu installed and working
- No in-progress infrastructure changes

```bash
# Verify OpenTofu is installed
tofu version

# Verify current state is readable
cd infrastructure/terraform
source .env
tofu plan
```

## Scheduled Passphrase Rotation

### Step 1: Generate New Passphrase

```bash
# Generate a secure random passphrase
openssl rand -base64 32
```

**Example output:**

```text
Xk8mN2pL9qR4sT6vW1yZ3bD5fG7hJ0kM
```

Save this securely - you'll need it in the next steps.

### Step 2: Backup Current State

```bash
cd infrastructure/terraform

# Source current credentials
source .env

# Create unencrypted backup (handle carefully!)
tofu show -json > /tmp/state-backup.json

# Also backup the encrypted state file
cp terraform.tfstate terraform.tfstate.backup
```

**Warning**: The unencrypted backup contains sensitive data. Delete after rotation.

### Step 3: Update Passphrase in Vault

```bash
# Edit SOPS vault
sops group_vars/all.sops.yaml
```

Update the passphrase:

```yaml
vault_state_encryption_passphrase: "NEW_PASSPHRASE_FROM_STEP_1"
```

Save and exit.

### Step 4: Re-source Environment

```bash
cd infrastructure/terraform

# Re-source to get new passphrase
source .env

# Verify the variable is set
echo $TF_VAR_state_encryption_passphrase | head -c 10
```

### Step 5: Refresh State with New Key

OpenTofu automatically re-encrypts state when the passphrase changes:

```bash
# Trigger state refresh (re-encrypts with new key)
tofu refresh

# Verify state is readable
tofu plan
```

If `tofu refresh` shows errors:

```bash
# Force state push with new encryption
tofu state push terraform.tfstate
```

### Step 6: Verify New Encryption

```bash
# State should be unreadable without passphrase
unset TF_VAR_state_encryption_passphrase
tofu show  # Should fail

# Re-source and verify it works
source .env
tofu show  # Should succeed
```

### Step 7: Cleanup

```bash
# Remove temporary backups (contains secrets!)
rm /tmp/state-backup.json
rm terraform.tfstate.backup

# Remove old passphrase from shell history
history -c
```

### Step 8: Commit Changes

```bash
# Only commit SOPS file (passphrase is encrypted)
git add group_vars/all.sops.yaml
git commit -m "chore: Rotate OpenTofu state encryption passphrase"
git push
```

## Emergency Passphrase Rotation (Compromise Response)

If the state encryption passphrase is potentially compromised:

### Immediate Actions

1. **Assume state contents are exposed** - includes API credentials, IPs, resource IDs
2. **Follow the scheduled rotation steps above** (Steps 1-7)
3. **Review what secrets were in state** (Step 8 below)
4. **Rotate exposed credentials** (Step 9 below)

### Step 8: Audit State Contents

Review what sensitive data was in the state:

```bash
cd infrastructure/terraform
source .env

# List all resources
tofu state list

# Show specific resource details
tofu state show proxmox_virtual_environment_vm.vms["jellyfin"]
```

Common sensitive items in state:

- VM IP addresses and MAC addresses
- Cloud-init user data (may contain bootstrap secrets)
- API endpoint URLs
- Resource identifiers

### Step 9: Rotate Exposed Credentials

If state contained bootstrap secrets or API credentials:

```bash
# Rotate Proxmox API credentials
./bin/bootstrap/create-proxmox-api-user.sh

# Regenerate Tailscale API key
# Visit: https://login.tailscale.com/admin/settings/keys

# Update vault with new credentials
sops group_vars/all.sops.yaml
```

### Step 10: Document Incident

Record in RECENT_CHANGES.md:

- Date and time of potential compromise
- Scope of exposure (what was in state)
- Credentials rotated
- Steps taken to remediate

## Recovery Procedures

### Lost Passphrase (Vault Accessible)

If you can decrypt the vault but forgot which passphrase is current:

```bash
# Extract from vault
sops -d group_vars/all.sops.yaml | grep vault_state_encryption_passphrase
```

### Lost Passphrase (Vault Inaccessible)

If both passphrase and age key are lost:

1. **State is unrecoverable** - cannot decrypt without original passphrase
2. **Option A**: Restore state from backup (if unencrypted backup exists)
3. **Option B**: Import existing infrastructure:

```bash
# Remove corrupted state
rm terraform.tfstate*

# Generate new passphrase
openssl rand -base64 32

# Update vault and source
sops group_vars/all.sops.yaml
source .env

# Re-import existing VMs
tofu import 'proxmox_virtual_environment_vm.vms["jellyfin"]' jellybuntu/qemu/400
tofu import 'proxmox_virtual_environment_vm.vms["nas"]' jellybuntu/qemu/300
# ... continue for all resources
```

### State File Corruption

If state file becomes corrupted:

```bash
# Try to read with current passphrase
source .env
tofu show

# If that fails, restore from backup
cp terraform.tfstate.backup terraform.tfstate

# If no backup, re-import infrastructure
```

## CI/CD Considerations

For Woodpecker CI pipelines that use OpenTofu:

### Environment Variable Setup

The passphrase must be available in CI environment:

```yaml
# .woodpecker/drift-detection.yml
steps:
  - name: detect-drift
    environment:
      - TF_VAR_state_encryption_passphrase
    secrets:
      - state_encryption_passphrase
```

### Secret Rotation in CI

When rotating passphrase:

1. Update SOPS vault (local)
2. Update Woodpecker secret (`state_encryption_passphrase`)
3. Verify CI pipeline can still access state

```bash
# Test CI passphrase manually
# (Extract from Woodpecker secrets UI and test locally)
```

## Verification Commands

```bash
# Verify passphrase is sourced
cd infrastructure/terraform
source .env
echo "Passphrase length: ${#TF_VAR_state_encryption_passphrase}"

# Verify state is readable
tofu show | head -20

# Verify state is encrypted on disk
head -c 100 terraform.tfstate
# Should show encrypted binary data, not JSON

# Test plan works
tofu plan
```

## Related Documentation

- [`infrastructure/terraform/README.md`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/README.md) - Complete OpenTofu documentation
- [SOPS Rotation](sops-rotation.md) - SOPS age key rotation procedures
- [Security Configuration](../configuration/security.md) - Overall security architecture
- [OpenTofu State Encryption](https://opentofu.org/docs/language/state/encryption/)
