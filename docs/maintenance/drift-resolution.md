# Infrastructure Drift Resolution Runbook

## Overview

**Drift** occurs when the actual infrastructure state diverges from the OpenTofu configuration.
The drift detection pipeline runs daily at 4 AM UTC to identify these discrepancies.

**Pipeline**: `.woodpecker/drift-detection.yml`
**Schedule**: Daily at 4 AM UTC (cron)
**Duration**: ~2-3 minutes

---

## Understanding Drift Detection Results

### Exit Codes

The drift detection pipeline uses `tofu plan -detailed-exitcode` which returns:

| Exit Code | Meaning | Pipeline Status |
|-----------|---------|-----------------|
| `0` | No drift detected | ✅ Success |
| `1` | Error running drift detection | ❌ Failure |
| `2` | Drift detected (changes needed) | ✅ Success (informational) |

**Note**: Exit code 2 is treated as success to avoid false alarms. Drift is informational, not a failure.

### Reading Drift Output

```text
OpenTofu will perform the following actions:

  # module.jellyfin.proxmox_virtual_environment_vm.vm will be updated in-place
  ~ resource "proxmox_virtual_environment_vm" "vm" {
      ~ memory {
          ~ dedicated = 8192 -> 10240
        }
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

**Key indicators**:

- `~` = Attribute will be changed in-place
- `+` = Resource will be created
- `-` = Resource will be destroyed
- `-/+` = Resource will be destroyed and recreated

---

## Drift Resolution Decision Tree

```text
Drift Detected
├─ Is this expected? (Manual change for testing/emergency)
│  ├─ YES → Update OpenTofu config to match infrastructure
│  └─ NO → Continue
│
├─ Does tofu plan show resource replacement? (-/+ or destroy)
│  ├─ YES → STOP! Investigate before applying
│  │         Check lifecycle ignore_changes configuration
│  └─ NO → Continue
│
├─ Is the drift in lifecycle ignore_changes attributes?
│  │  (SSH keys, clone source)
│  ├─ YES → FALSE POSITIVE - No action needed
│  └─ NO → Continue
│
├─ Is this a legitimate configuration drift?
│  ├─ YES → Apply OpenTofu config to fix drift
│  └─ NO → Update OpenTofu config to match reality
```

---

## Resolution Procedures

### Procedure 1: Apply OpenTofu Configuration (Fix Drift)

**When to use**: Infrastructure was manually changed but should match OpenTofu config.

**Steps**:

1. **Review the drift**:

   ```bash
   cd infrastructure/terraform
   source .env
   tofu plan
   ```

2. **Verify no replacements** (no `-/+` or `destroy` operations):

   ```bash
   # Look for these patterns in output
   # ✅ Safe: "~ memory { dedicated = 8192 -> 10240 }"
   # ❌ Unsafe: "-/+ resource will be replaced"
   # ❌ Unsafe: "Plan: 0 to add, 0 to change, 1 to destroy"
   ```

3. **Apply changes** (if safe):

   ```bash
   tofu apply
   ```

4. **Verify resolution**:

   ```bash
   tofu plan  # Should show 0 changes
   ```

### Procedure 2: Update OpenTofu Configuration (Accept Drift)

**When to use**: Manual infrastructure changes are intentional and should be permanent.

**Steps**:

1. **Identify what changed**:

   ```bash
   cd infrastructure/terraform
   source .env
   tofu plan  # Review differences
   ```

2. **Update configuration files**:
   - VM resources: Edit [`infrastructure/terraform/vms.tf`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/vms.tf)
   - Variables: Edit [`infrastructure/terraform/variables.tf`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/variables.tf)
   - Modules: Edit files in [`infrastructure/terraform/modules/*/`](https://github.com/SilverDFlame/jellybuntu/tree/main/infrastructure)

3. **Validate configuration**:

   ```bash
   tofu validate
   tofu plan  # Should show 0 changes
   ```

4. **Commit changes**:

   ```bash
   git add infrastructure/terraform/
   git commit -m "fix(terraform): Update config to match infrastructure state"
   git push
   ```

### Procedure 3: Investigate False Positives

**When to use**: Drift detected in `lifecycle { ignore_changes }` attributes.

**Steps**:

1. **Check ignored attributes**:

   ```bash
   grep -A5 "ignore_changes" infrastructure/terraform/modules/*/main.tf
   ```

   Current ignored attributes:

   - `initialization[0].user_account[0].keys` (SSH key format changes)
   - `clone` (Golden image rotation)

2. **Verify drift is in ignored attributes**:

   ```bash
   tofu plan | grep -E "(ssh_public_key|clone_vm_id)"
   ```

3. **If drift is in ignored attributes**: No action needed (false positive)

4. **If drift is NOT in ignored attributes**: Use Procedure 1 or 2

---

## Common Drift Scenarios

### Scenario 1: VM Memory Changed Manually in Proxmox

**Drift Output**:

```text
~ memory {
    ~ dedicated = 8192 -> 10240
  }
Plan: 0 to add, 1 to change, 0 to destroy.
```

**Resolution**:

- **If intentional**: Update `vms.tf` to reflect new memory value
- **If accidental**: Run `tofu apply` to restore original value

**Prevention**: Always use `tofu apply` for resource changes, not Proxmox UI

---

### Scenario 2: VM Startup Order Changed

**Drift Output**:

```text
~ startup {
    ~ order = 1 -> 2
  }
Plan: 0 to add, 1 to change, 0 to destroy.
```

**Resolution**:

- **If intentional**: Update `startup_order` in `vms.tf`
- **If accidental**: Run `tofu apply` to restore original order

**Prevention**: Document startup order changes in `vms.tf` comments

---

### Scenario 3: VM Tags Modified

**Drift Output**:

```text
~ tags = [
    - "old-tag",
    + "new-tag",
  ]
Plan: 0 to add, 1 to change, 0 to destroy.
```

**Resolution**: Update `tags` in `vms.tf` to match desired state

---

### Scenario 4: SSH Key Format Change (False Positive)

**Drift Output**:

```text
~ initialization {
    ~ user_account {
        ~ keys = ["ssh-ed25519 AAA..."] -> ["ssh-ed25519 AAA..."]
      }
  }
```

**Resolution**: **No action needed** - SSH keys are in `lifecycle { ignore_changes }`.
This is a cosmetic difference (same key, different format).

**Why this happens**: Proxmox provider sometimes reformats SSH keys without actually changing them.

---

### Scenario 5: Golden Image Rotation (False Positive)

**Drift Output**:

```text
~ clone {
    ~ vm_id = 9000 -> 9001
  }
```

**Resolution**: **No action needed** - `clone` is in `lifecycle { ignore_changes }`.
Golden image rotation only affects new VMs, not existing ones.

---

### Scenario 6: VM Destroyed/Recreated Outside OpenTofu

**Drift Output**:

```text
+ module.jellyfin.proxmox_virtual_environment_vm.vm will be created
Plan: 1 to add, 0 to change, 0 to destroy.
```

**Resolution**:

1. **STOP! Investigate why VM was destroyed**
2. Check Proxmox logs: `journalctl -u pve-cluster -n 100`
3. If VM was intentionally deleted, run `tofu apply` to recreate
4. If VM was accidentally deleted, restore from backup if available

**⚠️ WARNING**: Recreating a VM will result in data loss on the VM disk. NFS-mounted data is safe.

---

## Prevention Strategies

### 1. Always Use OpenTofu for Infrastructure Changes

**DON'T**: Make changes in Proxmox UI
**DO**: Update `vms.tf` and run `tofu apply`

### 2. Document Manual Emergency Changes

If you must make manual changes (emergency), immediately:

1. Document in incident log
2. Create follow-up task to update OpenTofu config
3. Test drift detection after manual change

### 3. Use Lifecycle Ignore Changes Wisely

Add attributes to `ignore_changes` only if:

- Changes are cosmetic (e.g., SSH key formatting)
- Changes should not trigger resource replacement (e.g., golden image rotation)
- Changes are managed outside OpenTofu (e.g., manual snapshots)

**Current ignored attributes**:

```hcl
lifecycle {
  ignore_changes = [
    initialization[0].user_account[0].keys,  # SSH key format
    clone,                                     # Golden image rotation
  ]
}
```

### 4. Review Drift Detection Output Weekly

Even if no drift is detected, review the pipeline logs weekly to ensure:

- Pipeline is running successfully
- No errors during `tofu init` or `tofu plan`
- SOPS decryption is working correctly

---

## Troubleshooting Drift Detection Pipeline

### Pipeline Fails with SOPS Decryption Error

**Error**: `failed to get the data key required to decrypt the SOPS file`

**Resolution**:

1. Verify `SOPS_AGE_KEY` secret is set in Woodpecker CI
2. Check SOPS key format (should be `AGE-SECRET-KEY-1...`)
3. Verify `vault.yml` is encrypted with correct AGE key

### Pipeline Fails with MinIO Connection Error

**Error**: `Failed to upload state to S3`

**Resolution**:

1. Verify NAS VM (192.168.0.15) is running
2. Check MinIO is running: `ssh nas.discus-moth.ts.net "systemctl --user status minio"`
3. Verify MinIO credentials in SOPS vault
4. Test MinIO connection: `curl http://nas.discus-moth.ts.net:9000`

### Pipeline Shows Unexpected Drift

**Resolution**:

1. Compare drift with recent Proxmox changes
2. Check if drift is in `lifecycle { ignore_changes }` attributes
3. Review recent commits to [`infrastructure/terraform/`](https://github.com/SilverDFlame/jellybuntu/blob/main/infrastructure/terraform/)
4. Use Procedure 3 (Investigate False Positives)

---

## Manual Drift Detection

To manually check for drift outside the CI pipeline:

```bash
cd infrastructure/terraform

# Load environment variables
source .env

# Initialize backend
tofu init

# Check for drift
tofu plan

# Show detailed changes
tofu show
```

---

## Related Documentation

- [Infrastructure Architecture](../architecture.md)
- [Golden Image Workflow](../deployment/golden-image-workflow.md)
- [Troubleshooting Guide](troubleshooting.md)

---

## Changelog

- **2024-12-16**: Initial drift resolution runbook created
- Added lifecycle ignore_changes for SSH keys and clone blocks
- Documented common drift scenarios and resolution procedures
