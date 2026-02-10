# UFW Firewall Troubleshooting

Troubleshooting guide for UFW (Uncomplicated Firewall) issues on Ubuntu VMs.

---

## Common Issues

### Issue: UFW Commands Fail with "binascii.Error: Non-hexadecimal digit found"

**Symptoms:**

- All UFW commands fail with Python traceback
- Error message: `binascii.Error: Non-hexadecimal digit found`
- Cannot view status, add rules, or reset firewall
- Ansible UFW role playbooks fail at "Set UFW default policies" task

**Example Error:**

```plaintext
Traceback (most recent call last):
  File "/usr/sbin/ufw", line 147, in <module>
    res = ui.do_action(pr.action, "", "", pr.force)
  ...
  File "/usr/lib/python3/dist-packages/ufw/util.py", line 1095, in hex_decode
    return binascii.unhexlify("%s" % (h[:-1] if len(h) % 2 else h)).decode(
binascii.Error: Non-hexadecimal digit found
```

**Cause:**

UFW stores rule comments as hex-encoded strings. Due to a known Ubuntu bug, these comments can become
corrupted, making the entire UFW database unreadable. Even basic commands like `ufw status` fail
because they try to decode the corrupted comments.

**Solution:**

Use the dedicated utility playbook to perform a hard reset:

```bash
# Step 1: Hard reset UFW (removes corrupted files)
./bin/runtime/ansible-run.sh playbooks/utility/reset-ufw-corrupted.yml --limit=nas

# Step 2: Immediately restore proper firewall rules
./bin/runtime/ansible-run.sh playbooks/infrastructure/nas.yml -e "ufw_reset=true"
```

**⚠️ WARNING:** The hard reset temporarily opens SSH to all IPs. Step 2 must be run immediately to
restore proper access controls.

**What the utility playbook does:**

1. Force disables UFW (ignoring errors)
2. Stops the UFW service
3. Deletes corrupted rules files:
   - `/etc/ufw/user.rules`
   - `/etc/ufw/user6.rules`
   - `/lib/ufw/user.rules`
   - `/lib/ufw/user6.rules`
4. Resets UFW to factory defaults
5. Enables UFW with temporary emergency SSH access
6. Prompts you to run the proper configuration playbook

**Prevention:**

This is a rare bug in Ubuntu's UFW implementation. There's no known way to prevent it, but running
firewall configuration playbooks regularly (with `ufw_reset=true`) can help catch corruption early.

---

### Issue: UFW Rules Not Applied After Playbook Run

**Symptoms:**

- Playbook completes successfully
- UFW shows old rules or no rules
- Services not accessible from expected networks

**Cause:**

UFW state may be cached or not properly reloaded after rule changes.

**Solution:**

Force a reset and reapply:

```bash
./bin/runtime/ansible-run.sh playbooks/system/system-hardening.yml -e "ufw_reset=true"
```

The `ufw_reset=true` flag tells the role to:

1. Reset UFW to clean state
2. Reapply all rules from host_vars
3. Enable UFW

**Verification:**

```bash
ssh ansible@hostname "sudo ufw status numbered"
```

---

### Issue: Cannot SSH After UFW Configuration

**Symptoms:**

- SSH connection refused or timeout after UFW playbook
- Lost access to VM

**Cause:**

- Firewall rules may be too restrictive
- SSH rule missing or incorrect network specified
- Tailscale network not properly configured

**Solution:**

**If you have console access (Proxmox):**

1. Access VM console through Proxmox

2. Disable UFW temporarily:

   ```bash
   sudo ufw disable
   ```

3. Verify SSH service is running:

   ```bash
   sudo systemctl status ssh
   ```

4. Check firewall rules in host_vars:

   ```bash
   cat host_vars/your-vm.yml
   ```

5. Fix rules and re-run playbook with reset:

   ```bash
   ./bin/runtime/ansible-run.sh playbooks/system/system-hardening.yml -e "ufw_reset=true"
   ```

**If you don't have console access:**

Use the bastion (NAS) VM to access:

```bash
ssh -i ~/.ssh/ansible_homelab -o ProxyJump=ansible@192.168.0.15 ansible@affected-vm-ip
```

See [SSH Bastion Documentation](../reference/ssh-bastion.md) for details.

**Prevention:**

Always ensure these rules are present in [`group_vars/all.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.yml):

```yaml
common_firewall_ports:
  - {port: 22, proto: tcp, from: "{{ tailscale_network }}", comment: "SSH from Tailscale"}
  - {port: 22, proto: tcp, from: "{{ local_network }}", comment: "SSH from LAN (fallback)"}
```

---

### Issue: Tailscale Network Not Accessible After UFW Enable

**Symptoms:**

- Tailscale connected but cannot access services
- `ping` works but service ports timeout

**Cause:**
UFW blocking Tailscale network traffic due to missing network rules.

**Solution:**

Verify Tailscale network is defined in [`group_vars/all.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.yml):

```yaml
tailscale_network: "100.64.0.0/10"
```

Check UFW rules include Tailscale network:

```bash
ssh ansible@hostname "sudo ufw status | grep 100.64"
```

If missing, re-run firewall configuration:

```bash
./bin/runtime/ansible-run.sh playbooks/system/system-hardening.yml -e "ufw_reset=true"
```

---

## Useful Commands

### Check UFW Status

```bash
# Verbose status
ssh ansible@hostname "sudo ufw status verbose"

# Numbered rules (easier to delete specific rules)
ssh ansible@hostname "sudo ufw status numbered"
```

### Manually Add Emergency SSH Rule

```bash
# From anywhere (emergency only)
ssh ansible@hostname "sudo ufw allow 22/tcp comment 'Emergency SSH'"

# From specific IP
ssh ansible@hostname "sudo ufw allow from YOUR_IP to any port 22"
```

### Manually Disable UFW (Emergency)

```bash
ssh ansible@hostname "sudo ufw disable"
```

### View UFW Logs

```bash
ssh ansible@hostname "sudo tail -f /var/log/ufw.log"
```

---

## Architecture Notes

### UFW Role Design

The `ufw_firewall` role ([`roles/ufw_firewall/`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/ufw_firewall/)) is designed to:

1. Merge common firewall ports (from [`group_vars/all.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.yml)) with host-specific ports (from `host_vars/`)
2. Set default policies (deny incoming, allow outgoing, deny routed)
3. Allow SSH from Tailscale network (100.64.0.0/10)
4. Allow SSH from local network (192.168.0.0/24) as fallback
5. Allow service ports from both Tailscale and local networks
6. Enable UFW firewall

### Reset Mechanism

The role includes a reset mechanism (lines 16-19 in [`roles/ufw_firewall/tasks/main.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/ufw_firewall/tasks/main.yml)):

```yaml
- name: Reset UFW to clean state (if needed)
  community.general.ufw:
    state: reset
  when: ufw_reset | default(false)
  ignore_errors: true
```

Activate by passing `-e "ufw_reset=true"` to any playbook that includes the UFW role.

### Network Security Philosophy

- **Default deny incoming**: All incoming connections blocked unless explicitly allowed
- **Tailscale primary**: Services accessible via Tailscale VPN network
- **Local network fallback**: Critical services (SSH, DNS) accessible from 192.168.0.0/24
- **No public exposure**: No services exposed to internet (0.0.0.0/0)

---

## Related Documentation

- [SSH Bastion Setup](../reference/ssh-bastion.md) - Emergency SSH access via NAS
- [Networking Configuration](../configuration/networking.md) - Network architecture and Tailscale setup
- UFW Firewall Role ([`roles/ufw_firewall/`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/ufw_firewall/)) - Role source code

---

## Utility Playbooks

- **Hard Reset Corrupted UFW**: [`playbooks/utility/reset-ufw-corrupted.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/playbooks/utility/reset-ufw-corrupted.yml)
  - Use when standard UFW commands fail due to database corruption
  - Removes all UFW files and resets to factory defaults
  - Requires immediate follow-up with proper configuration playbook

**See**: [Playbooks Reference](../reference/playbooks.md) for utility playbook documentation
