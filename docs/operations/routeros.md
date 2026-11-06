# MikroTik RouterOS (Ansible)

> Running the `routeros` role against the CCR1009 router and CRS326 switch: run-from rule, playbooks, credentials, recovery.

| Field | Value |
|-------|-------|
| **Devices** | `ccr1009` (192.168.10.1, router), `crs326` (192.168.10.2, switch), both RouterOS 7.18.2 |
| **Transport** | RouterOS API over api-ssl, port 8729, limited to 192.168.10.0/24; bootstrap over SSH port 663 |
| **Repo** | `jellybuntu` -> [`roles/routeros/`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/routeros) |
| **Tracking** | [gh#160](https://github.com/SilverDFlame/jellybuntu/issues/160), delivered as a series of 5 PRs |

## Status

PR 2 of 5 ([#441](https://github.com/SilverDFlame/jellybuntu/pull/441), merged 2026-11-06) delivered bootstrap, trust
anchors, read-only import and check runs, and a dead-man rehearsed on both devices. The role does **not** own the
routed or switched config yet (`routeros_config` arrives with PR 3 and PR 5), so a check run still ends with an
expected ownership-boundary failure: the device has export sections that are neither owned nor listed in
`routeros_not_owned_paths`.

### Known drift from IaC

The live devices differ from the repo in exactly two hand-made changes, both owner-approved and both to be codified
in PR 5:

| Device | Change | Why |
|---|---|---|
| `ccr1009` | Input accept `protocol=tcp dst-port=8729 src-mac-address=72:1D:5D:5D:0E:31 in-interface=!WAN`, above the flood rules (applied 2026-10-29) | Stops the controller banning itself ([gh#417](https://github.com/SilverDFlame/jellybuntu/issues/417), open until PR 5) |
| `crs326` | Default route gateway changed from the stale, inactive `192.168.0.1` to `192.168.10.1` (2026-11-05) | The switch had no route off VLAN 10, so its DNS to 9.9.9.9 could not work |

## Where things live

All paths are in [jellybuntu](https://github.com/SilverDFlame/jellybuntu):

| Path | Owns |
|---|---|
| [`inventory-routeros.ini`](https://github.com/SilverDFlame/jellybuntu/blob/main/inventory-routeros.ini) | The two devices. Separate from `inventory.ini` so they never join a `hosts: all` play |
| [`group_vars/routeros.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/routeros.yml) | Group-wide settings and `routeros_not_owned_paths` (export sections deliberately not owned, with reasons) |
| [`host_vars/ccr1009.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/ccr1009.yml) | CCR data: `routeros_controller_macs`, post-apply probes |
| [`host_vars/crs326.yml`](https://github.com/SilverDFlame/jellybuntu/blob/main/host_vars/crs326.yml) | CRS data: post-apply probes |
| [`files/routeros/`](https://github.com/SilverDFlame/jellybuntu/tree/main/files/routeros) | Trust anchors: pinned SSH host keys (`known_hosts`) and each device's CA certificate (`<host>-ca.pem`, public) |
| [`roles/routeros/README.md`](https://github.com/SilverDFlame/jellybuntu/blob/main/roles/routeros/README.md) | Role reference: engine passes, dead-man, controller guard, tests, known gaps |

## Run-from rule

Any run that includes `ccr1009` must come from a controller whose MAC is listed in `routeros_controller_macs`
(`host_vars/ccr1009.yml`). **Today that is only the Mac, on Wi-Fi.** That reflects the current state, not a design
limit: the Arch box and `automation` can be added (see [Adding a controller](#adding-a-controller)). A controller that
reaches the CCR through a router, not on-link, needs a guard fix first: its route lookup must honour `routing-table`.

!!! warning "An unlisted controller bans itself from the CCR for a day"
    The CCR input chain runs DoS and SynFlood detection above its LAN accept, with no WAN scoping. The binding rule
    is `DoS Attack Detection` (`protocol=tcp connection-limit=10,32`): more than 10 tracked TCP connections from one
    source address puts it on the `BlackList` address list for 1 day. A finished connection stays tracked for 10 to
    20s in its close states, and the role opens one TLS connection per API task, so an unlisted controller bans
    itself ([gh#417](https://github.com/SilverDFlame/jellybuntu/issues/417)). The accept rule in
    [Known drift](#known-drift-from-iac) lets api-ssl from the listed MAC skip the flood rules.

The controller guard enforces this. Preflight (check and apply runs) and import read the device's view of the
current API session (`/user active`, `/ip arp`, `/ip route`) and refuse unless every session of the run's user
resolves to a listed MAC. The guard runs only where `routeros_controller_macs` is non-empty. The CRS326 has no
filter rules, so it has no list and no guard.

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
| `routeros-bootstrap.yml --limit <host>` | One time per device over SSH 663: `ansible` and `ansible-ro` users and groups, CA and api-ssl cert, plain `api` off, CA fetched to `files/routeros/` | SSH key for the session; D1 age key (apply file) plus OpenBao for the RO password. `-e routeros_bootstrap_ro=false` skips the RO user and OpenBao, for a rebuild with OpenBao unreachable (wired, never run yet) |
| `routeros-import.yml` | Read-only dump to `/tmp/routeros-iac/import/<host>/`, 28 paths per device, files mode 0600, secret fields and `.id` dropped | OpenBao |
| `routeros.yml` | Check run: read-only, ends with the ownership boundary check | OpenBao |
| `routeros.yml -e routeros_apply=true` | Apply with the dead-man armed, one device at a time (`serial: 1`, any failure stops the play) | D1 age key; no OpenBao |
| `routeros-disarm.yml --limit <host>` | Remove a dead-man left armed by a failed apply or left by a restore, after verifying the device by hand | D1 age key; no OpenBao |

Every run also needs the main age key: `ansible.cfg` enables the `community.sops.sops` vars plugin, which decrypts
`group_vars/all.sops.yaml` for these hosts too.

From a worktree, runs that use OpenBao (check, import, RO bootstrap) also need
`-e openbao_ca_local_path=<main checkout>/files/generated/openbao-ca.pem`, because `*.pem` is gitignored and the CA
file is absent from a fresh worktree.

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

The CCR firewall is not owned by IaC until PR 5, so the accept rule goes on the device by hand, and it must exist
**before** the new controller's first API run or the controller bans itself for a day.

1. Run `bin/bootstrap/setup.sh` on the controller. It installs `librouteros==4.2.2` and `paramiko==5.0.0` into
   Ansible's Python environment.
2. Give the controller the main age key (every run) and, if it will apply, the D1 age key (apply, disarm, rehearsal).
3. For check runs and import, give it OpenBao access: the controller must be on the tailnet (the Ansible AppRole
   only issues tokens to tailnet sources) and needs the OpenBao CA at `files/generated/openbao-ca.pem` (or
   `-e openbao_ca_local_path=...`). The AppRole IDs come from `group_vars/all.sops.yaml`, covered by the main age
   key in step 2.
4. Pick a stable MAC. On macOS use a Fixed private address; it changes if the network is forgotten or network
   settings are reset, and then the rule and the list must be updated together.
5. By hand on the CCR (Winbox or SSH), add the input accept above the flood rules:
   `protocol=tcp dst-port=8729 src-mac-address=<MAC> in-interface=!WAN`, comment starting `routeros-iac controller`.
   Add a row for it to [Known drift](#known-drift-from-iac) and update the count in that section's first sentence:
   the rule is hand-made until PR 5 codifies it.
6. Add the MAC to `routeros_controller_macs` in `host_vars/ccr1009.yml` in a reviewed PR.
7. Confirm with a check run from the new controller: the guard must allow it.

## Recovery

- **Apply failed, API still reachable:** the dead-man stays armed (`pre-ansible.backup` plus a detached restore job)
  and the play stops before the next device. Verify the device by hand, then run `routeros-disarm.yml --limit <host>`
  inside the window (180s by default) and rerun. Preflight refuses a new apply while a left-behind job or backup
  exists, so the pre-run restore point is never overwritten.
- **Apply cut the API:** do nothing until the window expires. The restore job then loads `pre-ansible.backup` and
  the device reboots into its pre-run config. On CHR the reboot added about 25s to the window; on the real devices
  the restore has not fired, so the reboot time there is unmeasured. The restore leaves `pre-ansible.backup` on the
  device, so the next apply is refused until you clean up: verify the device is back on its pre-run config, run
  `routeros-disarm.yml --limit <host>`, fix whatever cut the API, then rerun.
- **Cannot reach the device at all:** MAC-Winbox or MAC-telnet from a host on the same L2 segment (enabled on all
  interfaces, checked 2026-10-13; `tool mac-server` is not owned by IaC, so re-check before relying on it), or the
  CCR1009 serial console (listed in the design spec; no test of it is recorded). Factory reset and reseed on real
  hardware is untested too: the seed block is only proven on CHR, so do it by hand first.

## Live record, 2026-11-05

- Both devices bootstrapped. RSA host keys pinned in `files/routeros/known_hosts` after the fingerprints matched from
  two network paths. The guard allowed the Mac on the real CCR (on-link ARP path).
- Read-only import: 28 paths per device.
- CCR rehearsal: the first attempt failed at the probe step (`probes.yml` read a role default from `hostvars`, where
  role defaults are not visible). The dead-man was disarmed inside the window, the fix landed, and the retry passed.
- CRS rehearsal passed after its default route was corrected by hand (see [Known drift](#known-drift-from-iac)).
- Slowest read per path in timed check runs: 0.75s (CCR), 1.21s (CRS), far below `routeros_deadman_window / 3`
  (60s), so no per-path window overrides.
