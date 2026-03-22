# Secrets

> All secrets are encrypted with [SOPS](https://github.com/getsops/sops) using an
> [age](https://github.com/FiloSottile/age) key. The encrypted vault file is safe to commit.

## Overview

Secrets live in
[`group_vars/all.sops.yaml`](https://github.com/SilverDFlame/jellybuntu/blob/main/group_vars/all.sops.yaml).
SOPS transparently decrypts the file at runtime using the age private key — Ansible and the
`./bin/runtime/ansible-run.sh` wrapper handle this automatically.

The age private key must be present at:

```text
~/.config/sops/age/keys.txt
```

This key is never committed. Store it in Bitwarden or another secure location.

## Editing Secrets

```bash
cd ~/coding/jellybuntu
sops group_vars/all.sops.yaml
```

SOPS opens the decrypted file in `$EDITOR`. Save and close to re-encrypt automatically.

## Viewing a Single Secret (without editing)

```bash
sops --decrypt group_vars/all.sops.yaml | grep vault_jellyfin_api_key
```

## Vault Variables Reference

All secrets are prefixed `vault_` and referenced in playbooks as `{{ vault_<name> }}`.

| Variable | Purpose |
|---|---|
| `vault_proxmox_password` | Proxmox API user password |
| `vault_tailscale_api_key` | Tailscale API key for generating ephemeral auth keys |
| `vault_nfs_uid` | NFS/container UID for file ownership (UID 3000) |
| `vault_nfs_gid` | NFS/container GID for file ownership (GID 3000) |
| `vault_sonarr_api_key` | Sonarr API key |
| `vault_radarr_api_key` | Radarr API key |
| `vault_sabnzbd_api_key` | SABnzbd API key |
| `vault_jellyfin_api_key` | Jellyfin API key |
| `vault_lidarr_api_key` | Lidarr API key |
| `vault_services_admin_username` | Admin username for media services |
| `vault_services_admin_password` | Admin password for media services |
| `vault_smm_ansible_password` | Satisfactory Mod Manager SFTP password |
| `vault_pia_username` | PIA VPN username |
| `vault_pia_password` | PIA VPN password |
| `vault_snmp_auth_password` | SNMP v3 auth password |
| `vault_snmp_priv_password` | SNMP v3 privacy password |
| `vault_state_encryption_passphrase` | OpenTofu state encryption passphrase |
| `vault_woodpecker_agent_secret` | Woodpecker CI agent secret |
| `vault_woodpecker_webhook_secret` | Woodpecker CI webhook secret |
| `vault_woodpecker_github_client` | Woodpecker GitHub OAuth client ID |
| `vault_woodpecker_github_secret` | Woodpecker GitHub OAuth client secret |
| `vault_discord_webhook_url` | Discord webhook for notifications |
| `vault_unifi_mongo_pass` | UniFi MongoDB user password |
| `vault_unifi_mongo_root_pass` | UniFi MongoDB root password |
| `vault_newshosting_username` | Newshosting Usenet username |
| `vault_newshosting_password` | Newshosting Usenet password |
| `vault_newshosting_connections` | Newshosting connection count |
| `vault_giganews_username` | Giganews Usenet username |
| `vault_giganews_password` | Giganews Usenet password |
| `vault_giganews_connections` | Giganews connection count |
| `vault_matrix_synapse_shared_secret` | Matrix Synapse registration secret |
| `vault_matrix_registration_shared_secret` | Matrix registration shared secret |
| `vault_matrix_postgres_password` | Matrix PostgreSQL password |
| `vault_matrix_livekit_api_key` | Matrix LiveKit API key |
| `vault_matrix_livekit_api_secret` | Matrix LiveKit API secret |
| `vault_matrix_coturn_auth_secret` | Matrix TURN server auth secret |
| `vault_matrix_form_secret` | Matrix form secret |
| `vault_media_postgres_password` | Media services PostgreSQL password |
| `vault_cloudflare_dns_api_token` | Cloudflare API token for DNS-01 challenges |
| `vault_flux_github_token` | GitHub token for Flux CD bootstrap |

## Rotating a Secret

1. Generate a new secret value (use a password manager or `openssl rand -base64 32`)
2. Edit the vault:

```bash
sops group_vars/all.sops.yaml
```

1. Update the relevant `vault_*` value, save, and close
1. Re-run the affected playbook to apply the new value:

```bash
./bin/runtime/ansible-run.sh playbooks/services/<service>.yml
```

1. If the secret is an API key used by multiple services (e.g., `vault_sonarr_api_key`),
   update the key in the service UI first, then update the vault, then re-run playbooks.

## Adding a New Secret

1. Open the vault with `sops group_vars/all.sops.yaml`
2. Add a new `vault_<name>: <value>` entry
3. Reference it in playbooks or `group_vars/all.yml` as `{{ vault_<name> }}`
4. Commit the updated (encrypted) `all.sops.yaml`

## Age Key Backup

The age key is the single point of failure for secret decryption. Back it up:

```bash
# Export to Bitwarden secure note or offline storage
cat ~/.config/sops/age/keys.txt
```

If the key is lost, all secrets in `all.sops.yaml` become permanently inaccessible and must
be rotated from the services' UIs, then re-entered into a fresh vault.
