# Tailscale Auto-Approval Setup

This guide explains how to configure Tailscale to automatically approve ephemeral devices with the `homelab` tag.

## Why Auto-Approval?

When VMs are powered down and restarted, ephemeral Tailscale auth keys expire. The power management playbook
automatically generates new ephemeral keys and reconnects VMs to Tailscale. To avoid manually approving these devices
each time, you can configure auto-approval using ACL tags.

## Option 1: Auto-Approve Devices with Tag (Recommended)

This approach uses Tailscale's ACL (Access Control List) to automatically approve devices tagged with `tag:homelab`.

### Steps

1. **Access Tailscale Admin Console**
   - Go to https://login.tailscale.com/admin/acls

2. **Edit ACL Policy**
   - Add or update the ACL to include auto-approval for tagged devices:

```json
{
  "tagOwners": {
    "tag:homelab": ["autogroup:admin"]
  },
  "autoApprovers": {
    "routes": {
      "0.0.0.0/0": ["tag:homelab"],
      "::/0": ["tag:homelab"]
    },
    "exitNode": ["tag:homelab"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["tag:homelab"],
      "dst": ["*:*"]
    },
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["tag:homelab:*"]
    }
  ]
}
```

1. **Save the ACL**
   - Click "Save" to apply the changes

### What This Does

- **tagOwners**: Allows admin users to assign the `tag:homelab` tag to devices
- **autoApprovers**: Automatically approves devices with `tag:homelab` tag
- **acls**: Allows tagged devices to communicate with all other devices on your Tailscale network

## Option 2: Generate API Key with Auto-Approval

If you prefer to use API keys with built-in auto-approval, you can generate a new API key with the necessary permissions.

### Steps

1. **Go to API Keys Settings**
   - Visit: https://login.tailscale.com/admin/settings/keys

2. **Generate New API Key**
   - Click "Generate API key"
   - Description: `Homelab Automation - Ephemeral Auto-Approved`
   - Permissions: Select "Write" for "Devices"

3. **Update Secrets File with New API Key**

   ```bash
   sops group_vars/all.sops.yaml
   ```

   Update the Tailscale API key:

   ```yaml
   vault_tailscale_api_key: "tskey-api-XXXXXXXXXXXXXXXXX"
   ```

4. **Verify Auth Key Generation**

   The power management playbook and Tailscale configuration playbook already generate auth keys with these settings:
   - `reusable: false` - Single-use keys
   - `ephemeral: true` - Devices removed when disconnected
   - `preauthorized: true` - Auto-approved (requires ACL or API key with proper permissions)
   - `tags: ["tag:homelab"]` - Tagged for ACL-based auto-approval

## Current Implementation

The following playbooks already generate ephemeral, preauthorized auth keys with the `tag:homelab` tag:

- [`playbooks/networking/tailscale.yml`][tailscale-playbook]
- [`playbooks/utility/power-management.yml`][power-playbook]

[tailscale-playbook]: https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/networking/tailscale.yml
[power-playbook]: https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/utility/power-management.yml

To enable auto-approval, you just need to configure the ACL policy (Option 1) in the Tailscale admin console.

## Testing Auto-Approval

After configuring the ACL:

1. **Shutdown VMs**

   ```bash
   ./bin/runtime/ansible-run.sh playbooks/utility/power-management.yml -e power_action=shutdown
   ```

2. **Startup VMs** (will automatically reconnect to Tailscale)

   ```bash
   ./bin/runtime/ansible-run.sh playbooks/utility/power-management.yml -e power_action=startup
   ```

3. **Verify in Tailscale Admin**
   - Go to https://login.tailscale.com/admin/machines
   - Check that the VMs are listed and automatically approved
   - Look for the `homelab` tag on the devices

## Troubleshooting

### Devices Not Auto-Approved

- Verify the ACL is saved correctly
- Check that the API key has "Write" permissions for "Devices"
- Ensure the `tag:homelab` is included in the auth key generation

### ACL Syntax Errors

- Use the Tailscale ACL editor's syntax checker
- Refer to official docs: https://tailscale.com/kb/1018/acls/

### API Key Not Working

- Regenerate the API key with proper permissions
- Update the vault with the new key
- Test key generation manually:

  ```bash
  curl -X POST https://api.tailscale.com/api/v2/tailnet/-/keys \
    -H "Authorization: Bearer YOUR_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"capabilities":{"devices":{"create":{"reusable":false,"ephemeral":true,"preauthorized":true,"tags":["tag:homelab"]}}}}'
  ```

## References

- [Tailscale ACLs Documentation](https://tailscale.com/kb/1018/acls/)
- [Tailscale Auth Keys API](https://tailscale.com/kb/1101/api/#tailnet-keys-post)
- [Tailscale Tags](https://tailscale.com/kb/1068/acl-tags/)
