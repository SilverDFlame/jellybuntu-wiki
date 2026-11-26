# MikroTik RouterOS (Ansible)

> Running the `routeros` role against the CCR1009 router and CRS326 switch: run-from rule, playbooks, credentials, re-flash, recovery.

| Field | Value |
|-------|-------|
| **Devices** | `ccr1009` (192.168.10.1, router), `crs326` (192.168.10.2, switch), both RouterOS and RouterBOOT 7.25.2 |
| **Transport** | RouterOS API over api-ssl, port 8729, limited to 192.168.10.0/24; bootstrap and boundary export over SSH port 663, limited to 192.168.10.0/24 and 100.64.0.0/10 |
| **Repo** | `jellybuntu` -> [`roles/routeros/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/routeros) |
| **Tracking** | [gh#160](https://github.com/SilverDFlame/jellybuntu/issues/160), closed by PR 5 of 5 ([#449](https://github.com/SilverDFlame/jellybuntu/pull/449)) |

## Status

Both devices are fully under `roles/routeros`: each owns all 30 paths in `routeros_path_order`, and nothing is
pending (`routeros_pending_paths: {}`). Tier 2 was applied live on 2026-11-10 with zero change, and both devices kept
every owned path across a reboot. Every later change (see [Live changes since tier 2](#live-changes-since-tier-2))
was applied with the dead-man armed and closed with a check run at `changed=0` on both devices.

Drift detection in CI waits for the new self-hosted CI: the `ansible-drift` pipeline is disabled
([#408](https://github.com/SilverDFlame/jellybuntu/pull/408)). Until then, run the check by hand from the Mac:

```bash
mise run routeros-play -- playbooks/networking/routeros.yml
```

### Known drift from IaC

None. The two hand-made changes recorded here before PR 5 (the CCR controller accept rule for
[gh#417](https://github.com/SilverDFlame/jellybuntu/issues/417) and the CRS default route via `192.168.10.1`) are both
owned in host data now. A check run that reports any change is new drift: find out who made it before applying over it.

## Where things live

All paths are in [jellybuntu](https://github.com/SilverDFlame/jellybuntu):

| Path | Owns |
|---|---|
| [`inventory-routeros.ini`](https://github.com/SilverDFlame/jellybuntu/blob/main/inventory-routeros.ini) | The two devices. Separate from `inventory.ini` so they never join a `hosts: all` play |
| [`group_vars/routeros.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/routeros.yml) | Group-wide settings and `routeros_not_owned_paths` (export sections deliberately not owned, with reasons) |
| [`host_vars/ccr1009.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/ccr1009.yml) | CCR data: `routeros_controller_macs`, `routeros_mgmt`, post-apply probes, `routeros_config` (every owned path) |
| [`host_vars/crs326.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/crs326.yml) | CRS data: `routeros_mgmt`, post-apply probes, `routeros_config` (every owned path) |
| [`files/routeros/`](https://github.com/SilverDFlame/jellybuntu/tree/main/files/routeros) | Trust anchors: pinned ED25519 SSH host keys (`known_hosts`) and each device's CA certificate (`<host>-ca.pem`, public) |
| [`roles/routeros/README.md`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/routeros/README.md) | Role reference: engine passes, dead-man, controller guard, seed, tests, known gaps |

## Run-from rule

Any run that includes `ccr1009` must come from a controller whose MAC is listed in `routeros_controller_macs`
(`host_vars/ccr1009.yml`). **Today that is only the Mac, on Wi-Fi.** That reflects the current state, not a design
limit: the Arch box and `automation` can be added (see [Adding a controller](#adding-a-controller)). A controller that
reaches the CCR through a router, not on-link, needs a guard fix first: its route lookup must honour `routing-table`.

The controller guard enforces this. Preflight (check and apply runs) and import read the device's view of the
current API session (`/user active`, `/ip arp`, `/ip route`) and refuse unless every session of the run's user
resolves to a listed MAC. The guard runs only where `routeros_controller_macs` is non-empty. The CRS326 has no
filter rules, so it has no list and no guard.

!!! note "Why the guard exists: the CCR flood rules once banned the controller"
    The CCR input chain runs DoS and SynFlood detection above its LAN accept. Until RouterOS 7.25.2
    ([#482](https://github.com/SilverDFlame/jellybuntu/pull/482)) the two detection rules had no interface scope:
    more than 10 tracked TCP connections from one source put it on `BlackList` for 1 day, and the role opens one TLS
    connection per API task, so a controller banned itself
    ([gh#417](https://github.com/SilverDFlame/jellybuntu/issues/417)). Both detection rules now carry
    `in-interface: WAN`, with a regression test. Each listed MAC also keeps an owned input accept for tcp 8729 above
    the flood rules, and a gate test fails the data if that accept is missing or placed below them.

!!! warning "Never use `bin/runtime/ansible-run.sh` for these playbooks"
    It reads `inventory.ini`, which has no RouterOS hosts.

Use the mise runner, which also unsets the `ANSIBLE_CONFIG`, `ANSIBLE_INVENTORY` and `ANSIBLE_ROLES_PATH` pins so it
works from a worktree:

```bash
mise run routeros-play -- playbooks/networking/<playbook> [args]
```

## Playbooks

| Playbook | What | Credentials |
|---|---|---|
| `routeros-bootstrap.yml --limit <host>` | One time per device over SSH 663: `ansible` and `ansible-ro` users and groups, CA and api-ssl cert, CA trusted for the API only, plain `api` off, CA fetched to `files/routeros/` | SSH key for the session; D1 age key (apply file) plus OpenBao for the RO password. `-e routeros_bootstrap_ro=false` skips the RO user and OpenBao, for a rebuild with OpenBao unreachable (wired, never run yet) |
| `routeros-import.yml` | Read-only dump to `/tmp/routeros-iac/import/<host>/`, 30 paths per device, files mode 0600, secret fields and `.id` dropped | OpenBao |
| `routeros-seed.yml --limit <host>` | Renders the factory-reset seed `/tmp/routeros-iac/seed/<host>.rsc` (0600). Local only, no device contact | None |
| `routeros.yml` | Check run: read-only, ends with the ownership boundary check | OpenBao |
| `routeros.yml -e routeros_apply=true` | Apply with the dead-man armed, one device at a time (`serial: 1`, any failure stops the play) | D1 age key; no OpenBao |
| `routeros-disarm.yml --limit <host>` | Remove a dead-man left armed by a failed apply or left by a restore, after verifying the device by hand | D1 age key; no OpenBao |

Every run also needs the main age key: `ansible.cfg` enables the `community.sops.sops` vars plugin, which decrypts
`group_vars/all.sops.yaml` for these hosts too.

From a worktree, runs that use OpenBao (check, import, RO bootstrap) also need
`-e openbao_ca_local_path=<main checkout>/files/generated/openbao-ca.pem`, because `*.pem` is gitignored and the CA
file is absent from a fresh worktree.

Every check and apply run also sets the bootstrap CA (`ansible-ca`) to `trust-store=api`
([#486](https://github.com/SilverDFlame/jellybuntu/pull/486)). A device without `ansible-ca` fails the run at that
task, so a device must be bootstrapped before its first check run.

### Rehearsal

A rehearsal arms the dead-man, holds, runs the probes and disarms. It applies nothing. Its extra vars go in a file:
`-e routeros_config={}` would pass the string `"{}"`, not a dict.

```bash
cat > /tmp/routeros-rehearsal.yml <<'VARS'
routeros_apply: true
routeros_config: {}
routeros_rehearsal: true
routeros_deadman_window: 600
VARS
mise run routeros-play -- playbooks/networking/routeros.yml --limit ccr1009 -e @/tmp/routeros-rehearsal.yml
```

Keep a Winbox or terminal session open on the device while it runs. If it fails after arming, run
`routeros-disarm.yml --limit <host>` inside the window (600s here).

## Credentials

| Credential | User and policy | Where | Used by |
|---|---|---|---|
| Apply password | `ansible`: `read,write,api,policy,reboot,test,sensitive` | `secrets/routeros-apply.sops.yaml` (D1 key) | Apply, disarm, rehearsal, bootstrap |
| Backup password | Encrypts `pre-ansible.backup` | `secrets/routeros-apply.sops.yaml` (D1 key) | Apply, rehearsal |
| Read-only password | `ansible-ro`: `read,api,ssh` (cannot write) | OpenBao `secret/jellybuntu/network/routeros_ro_password`, looked up in `group_vars/all.yml` | Check runs, import, CI drift checks, bootstrap |

- **The D1 key** is a separate age recipient that only `secrets/routeros-apply.sops.yaml` uses (`.sops.yaml` rule
  placed before the catch-all). It is never on CI, so a compromised CI cannot write to the network. It is in the
  Mac's age key file; the Arch box copy has not been confirmed.
- **Apply credentials are deliberately not in OpenBao.** OpenBao is a single file-backed instance with manual unseal;
  a sealed vault must never block recovery. Apply, disarm and rehearsal touch only SOPS, so break-glass works with
  OpenBao sealed or unreachable.
- All three passwords must match `^[A-Za-z0-9._+-]{16,}$` (the backup password is passed unquoted into RouterOS
  scripts, and preflight refuses an unsafe one before any device write). They are never printed: every task carrying
  one has `no_log` and `diff: false`, enforced by the gate test `tests/routeros/test_secret_tasks.py`.

## Adding a controller

The CCR firewall is owned by IaC, so the new controller's accept rule goes into host data, never on the device by
hand. It must be applied **before** the new controller's first API run, or the guard refuses the run.

1. Run `bin/bootstrap/setup.sh` on the controller. It installs `librouteros==4.2.2` and `paramiko==5.0.0` into
    Ansible's Python environment.
2. Install the collections: `ansible-galaxy collection install -r requirements.yml --force` (pins
    `community.routeros` 3.24.0; runs stop on the pin guard with any other version).
3. Give the controller the main age key (every run) and, if it will apply, the D1 age key (apply, disarm, rehearsal).
4. For check runs and import, give it OpenBao access: the controller must be on the tailnet (the Ansible AppRole
    only issues tokens to tailnet sources) and needs the OpenBao CA at `files/generated/openbao-ca.pem` (or
    `-e openbao_ca_local_path=...`). The AppRole IDs come from `group_vars/all.sops.yaml`, covered by the main age
    key in step 3.
5. Pick a stable MAC. On macOS use a Fixed private address; it changes if the network is forgotten or network
    settings are reset, and then the rule and the list must be updated together.
6. In one reviewed PR against `host_vars/ccr1009.yml`:
    - add the MAC to `routeros_controller_macs`;
    - add an `ip firewall filter` input accept for it above the flood rules, modelled on the existing one:
      `protocol: tcp`, `dst-port: 8729`, `src-mac-address: <MAC>`, `in-interface: '!WAN'`, comment starting
      `routeros-iac controller`. The gate test fails the PR if the accept is missing or below the flood rules.
7. From an existing controller (the Mac), run the check, then the armed apply, against `ccr1009`.
8. Confirm with a check run from the new controller: the guard must allow it, and the run must report `changed=0`.

## Re-flash a device

Use this when a device has to be rebuilt from git, for example after a factory reset or a replacement on the same
hardware model. Every value comes from `host_vars/<host>.yml`. The role README's
[Seed and re-flash](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/routeros/README.md#seed-and-re-flash)
section is the reference; this is the operator order.

!!! warning "Not yet done on real hardware"
    No real-hardware re-flash has been carried out. The seed, bootstrap and apply sequence is covered on CHR 7.25.2
    (Molecule scenario `rebuild`) and by seed renders from the real host data. Read [Known gaps](#re-flash-known-gaps)
    before you start, and keep a console open throughout.

### Before you start

- Use the Mac: it holds the controller MAC accept rule, the D1 age key, the main age key and
  `~/.ssh/ansible_homelab.pub` (the seed's `routeros_bootstrap_pubkey`).
- Make sure the Mac has the pinned collections: `ansible-galaxy collection install -r requirements.yml --force`
  (`community.routeros` 3.24.0; the role refuses to run on another version).
- If the device still answers, take an off-device backup first: `/export file=<host>-pre-reflash` (config, no
  secrets) and `/system backup save name=<host>-pre-reflash password=<a password you keep>` (holds secrets). Copy
  both files to the Mac, mode 600, outside any repo.
- Keep MAC-Winbox, MAC-telnet or the CCR serial console ready; that is your path in until the seed has run. For the
  CCR, plan on the serial console or a cable straight into the device: its management VLAN reaches it tagged on
  `10G-LAN`, so MAC-telnet from the Mac over Wi-Fi probably cannot reach a reset CCR (unverified).
- Give the Mac a static `192.168.10.x` address before you start. Bootstrap users and api-ssl accept only
  192.168.10.0/24, and during a CCR outage nothing hands out DHCP.
- Steps 5 to 7 run from **one jellybuntu worktree** (the branch holding the new trust anchors). The main checkout
  still holds the old host key and CA, so a check or apply from there fails the TLS and SSH logins until the PR
  merges. Every OpenBao run from that worktree needs
  `-e openbao_ca_local_path=<main checkout>/files/generated/openbao-ca.pem` (see [Playbooks](#playbooks)).
- A reset keeps the installed RouterOS. For a replacement unit or a broken install, netinstall RouterOS 7.25.2 first
  (the `tile` package for the CCR, `arm` for the CRS) with no configuration, upgrade the firmware
  (`/system routerboard upgrade`, then reboot) so RouterBOOT is 7.25.2 too, and continue at step 3. The netinstall
  path has not been exercised here.
- CCR outage: no routing, NAT or DHCP for the household until step 6 finishes.
- CRS outage: after the reset, no switching at all. The seed (step 4) brings back only the VLAN 10 management ports
  and trunks. Every other port and VLAN returns in step 6.

### Steps

1. **Render the seed.**
    - Run `mise run routeros-play -- playbooks/networking/routeros-seed.yml --limit <host>`.
    - Output: `/tmp/routeros-iac/seed/<host>.rsc`. macOS purges `/tmp` after 3 days, so render it just before the
      rebuild.
    - The file contains no secret. The bootstrap user (`routeros_bootstrap_user`) gets your public key and a random
      password generated on the device, and the seed disables `admin`.
2. **Reset the device.**
    - Run `/system reset-configuration no-defaults=yes skip-backup=yes`.
    - The seed refuses to run if any bridge exists, which catches a reset that left the vendor defaults in place.
3. **Move SSH to port 663.**
    - On the console, as `admin`, before the seed: `/ip service set ssh port=663`.
    - The seed does not set the SSH port, and bootstrap connects on 663 (`routeros_bootstrap_port`). A reset device
      listens on 22. The apply in step 6 owns `ip service` and would set 663 too, but bootstrap needs it first.
    - This step works around a known gap,
      [#488](https://github.com/SilverDFlame/jellybuntu/issues/488): the seed should set port 663 itself. Once #488
      merges, the seed emits this line and the step goes away.
4. **Paste the seed** over MAC-telnet or the serial console, as one block. Afterwards the device answers on VLAN 10
    at its management address:
    - CCR: `192.168.10.1` on `vlan10-mgmt` over `10G-LAN` (the renamed `sfp-sfpplus1`).
    - CRS: `192.168.10.2` on `vlan10-mgmt` over the VLAN-filtering `bridge`, with a default route via the CCR.
5. **Re-pin the host key, then bootstrap.** The order is fixed: port 663 (step 3), then the scan (it needs 663),
    then bootstrap (it fails its first login on a missing or mismatched key).
    - The reset device has a new SSH host key. Bootstrap merges `files/routeros/known_hosts` into `~/.ssh/known_hosts`,
      and a device whose key differs from the pinned line fails the SSH login. Read the new ED25519 key from two
      network paths, check they match, and replace the `[<ip>]:663` line in `files/routeros/known_hosts` on a branch.
      The method used for the 7.25.2 re-pin:
        - path 1, from the Mac: `ssh-keyscan -p 663 -t ed25519 <ip>`;
        - path 2, from the Proxmox host over the tailnet:
          `ssh root@jellybuntu.discus-moth.ts.net "ssh-keyscan -p 663 -t ed25519 <ip>"`. During a CCR outage the
          tailnet may be down (no WAN); use any second host with an interface on 192.168.10.0/24 instead (with the CCR down
          nothing routes between VLANs; unverified which hosts qualify);
        - a third check: the device log line for the key generation, if it is still in RAM.
    - From that branch's worktree, run
      `mise run routeros-play -- playbooks/networking/routeros-bootstrap.yml --limit <host> -e openbao_ca_local_path=<main checkout>/files/generated/openbao-ca.pem`.
    - It creates the `ansible` and `ansible-ro` users and groups and the private CA, sets the CA to `trust-store=api`,
      turns plain `api` off, restricts api-ssl to the management subnet, and fetches the new CA cert to
      `files/routeros/<host>-ca.pem` (retried 12 x 5s, [#484](https://github.com/SilverDFlame/jellybuntu/pull/484)).
    - It needs the D1 age key plus OpenBao. If OpenBao is down, swap the `openbao_ca_local_path` var for
      `-e routeros_bootstrap_ro=false` and rerun it later without that flag; the check run in step 6 needs the RO user.
    - Commit the new `known_hosts` line and `<host>-ca.pem` together and open the PR. It merges after step 7.
6. **Check, then apply**, from the same worktree.
    - Run the check:
      `mise run routeros-play -- playbooks/networking/routeros.yml --limit <host> -e openbao_ca_local_path=<main checkout>/files/generated/openbao-ca.pem`.
      It is read-only and needs OpenBao. On a re-flashed device it reports most paths as changed; that is expected. Among them is
      `certificate settings`: a fresh device has `builtin-trust-store=default`, and the apply sets `untrusted`.
    - Then the armed apply:
      `mise run routeros-play -- playbooks/networking/routeros.yml --limit <host> -e routeros_apply=true`. It needs
      the D1 and main age keys.
    - The dead-man restores the pre-apply backup if the API is lost mid-run. On a re-flashed device that backup is the
      post-bootstrap state, so a restore lands you back at the start of step 6, not at the old config.
7. **Confirm.**
    - A second check run (the step 6 check command, same worktree) reports `changed=0` and the boundary check passes.
    - Monitoring shows `up{job="snmp-mikrotik"} == 1` for the device.
    - Merge the trust-anchor PR from step 5, then pull the main checkout so later runs from there see the new key
      and CA.

### Re-flash known gaps

- **Not yet done on hardware.** See the warning above.
- **Seed SSH port.** The seed leaves SSH on 22, hence the manual step 3
  ([#488](https://github.com/SilverDFlame/jellybuntu/issues/488)). Molecule cannot catch this: the harness
  reaches CHR SSH through port 22 on purpose.
- **Console paste.** Molecule sends the seed as one line over SSH. Pasting the multi-line file into an interactive
  console is unverified on a device. If the paste errors part-way, reset again and repeat from step 2.
- **CRS switch paths.** CHR has no switch chip, so `prod_crs326` excludes `interface ethernet`, `interface bridge
  port`, `interface bridge vlan`, `interface list member` and `ip dhcp-client`. Those paths have only ever been
  applied as modifies to the live CRS, never created from scratch.
- **Ethernet defaults.** `interface ethernet` owns only the fields the import shows, plus `disabled`. A field left
  at its default (for example `mtu` 1500) is not owned.

Settled since PR 5: the CCR `NAT` rule no longer carries `realm: ''`, which RouterOS rejected on create
([#469](https://github.com/SilverDFlame/jellybuntu/pull/469)), and the CCR DHCP servers' `address-lists: ''` is
accepted on create ([#471](https://github.com/SilverDFlame/jellybuntu/pull/471)).

## Recovery

- **Apply failed, API still reachable:** the dead-man stays armed (`pre-ansible.backup` plus a detached restore job)
  and the play stops before the next device. Verify the device by hand, then run `routeros-disarm.yml --limit <host>`
  inside the window (180s by default) and rerun. Preflight refuses a new apply while a left-behind job or backup
  exists, so the pre-run restore point is never overwritten.
- **Apply failed with "dead-man job was already gone at disarm":** the job vanished or fired before the closing
  disarm ([#478](https://github.com/SilverDFlame/jellybuntu/pull/478)). The run reports state `backup`, not armed: no
  restore is promised, but one may already be under way. Wait out the window, check by hand which config the device
  is on, then run `routeros-disarm.yml --limit <host>` to clear the backup.
- **Apply cut the API:** do nothing until the window expires. The restore job then loads `pre-ansible.backup` and
  the device reboots into its pre-run config. On CHR the reboot added about 25s to the window. On the real CRS a
  restore fired once (2026-11-21, [#476](https://github.com/SilverDFlame/jellybuntu/pull/476)): it rebooted about
  2 min after the failure and came back on its pre-apply config. The restore leaves `pre-ansible.backup` on the
  device, so the next apply is refused until you clean up: verify the device is back on its pre-run config, run
  `routeros-disarm.yml --limit <host>`, fix whatever cut the API, then rerun.
- **Cannot reach the device at all:** MAC-Winbox or MAC-telnet from a host on the same L2 segment (enabled on all
  interfaces, checked 2026-10-13; `tool mac-server` is not owned by IaC, so re-check before relying on it), or the
  CCR1009 serial console (listed in the design spec; no test of it is recorded). If the config cannot be saved,
  [re-flash the device](#re-flash-a-device).

## Live record

### Bootstrap, 2026-11-05

- Both devices bootstrapped. RSA host keys pinned in `files/routeros/known_hosts` after the fingerprints matched from
  two network paths (replaced by ED25519 keys with 7.25.2, see below). The guard allowed the Mac on the real CCR
  (on-link ARP path).
- Read-only import: 28 paths per device (30 since `ip neighbor discovery-settings` and `certificate settings`).
- CCR rehearsal: the first attempt failed at the probe step (`probes.yml` read a role default from `hostvars`, where
  role defaults are not visible). The dead-man was disarmed inside the window, the fix landed, and the retry passed.
- CRS rehearsal passed after its default route was corrected by hand (since owned in host data).
- Slowest read per path in timed check runs: 0.75s (CCR), 1.21s (CRS), far below `routeros_deadman_window / 3`
  (60s), so no per-path window overrides.

### Live changes since tier 2

Each was applied with the dead-man armed after a read-only check, and closed with `changed=0` on both devices.

| PR | Merged | Change on the devices |
|---|---|---|
| [#460](https://github.com/SilverDFlame/jellybuntu/pull/460) | 2026-11-11 | LLDP only, only on the `INFRA` interface list (CCR `10G-LAN`; CRS `ether1`, `ether3`, `sfp-sfpplus1`, `sfp-sfpplus2`); CRS SFP+ comments corrected (CCR is on `sfp-sfpplus2`) |
| [#467](https://github.com/SilverDFlame/jellybuntu/pull/467) | 2026-11-18 | Dead VLAN 99 / OPNsense transit removed: CCR `vlan99-transit`, its /30, the route via `192.168.99.1` and three NAT rules; CRS `ether15` left the bridge |
| [#469](https://github.com/SilverDFlame/jellybuntu/pull/469) | 2026-11-18 | CCR `NAT` rule `realm: ''` unset in place |
| [#471](https://github.com/SilverDFlame/jellybuntu/pull/471) | 2026-11-18 | CCR legacy `lan` DHCP scope on `bridge` removed; `time-zone-autodetect` off; SSH 663 limited to mgmt plus tailnet |
| [#476](https://github.com/SilverDFlame/jellybuntu/pull/476) | 2026-11-22 | CRS NTP client on (`0-3.pool.ntp.org`). The first attempt (2026-11-21) failed and the dead-man rolled the CRS back; the retry passed |
| [#482](https://github.com/SilverDFlame/jellybuntu/pull/482) | 2026-11-24 | RouterOS and RouterBOOT 7.18.2 to 7.25.2 (by hand, 2026-11-23), then: `available-from` replaces `address` in `ip service`, `reverse-proxy` owned disabled, `builtin-trust-store: untrusted` on both, flood detection scoped to `WAN`, ED25519 host keys re-pinned |
| [#486](https://github.com/SilverDFlame/jellybuntu/pull/486) | 2026-11-26 | CRS `bridge` DHCP client removed; `ansible-ca` trusted for the API only |
