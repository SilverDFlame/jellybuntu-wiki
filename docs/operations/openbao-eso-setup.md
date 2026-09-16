# OpenBao + External Secrets Operator Setup

One-time manual setup connecting OpenBao (VM 510) to k3s's External
Secrets Operator (ESO). Not Ansible-automated: automating it would require
storing an OpenBao admin-equivalent token somewhere Ansible can read,
which defeats the point of moving secrets out of SOPS. Run this by hand,
once, after
[`roles/openbao`](https://github.com/SilverDFlame/jellybuntu/tree/main/roles/openbao)
has installed the server and it's been manually unsealed.

Commands and flag names below were run and verified live against OpenBao
2.6.2 on 2026-09-15 — not copied from Vault documentation. OpenBao's
`bao` CLI has a few behavioral differences from HashiCorp Vault's `vault`
CLI that this runbook works around explicitly (see callouts below).

## Prerequisites

- OpenBao is unsealed (`bao status` on the VM shows `Sealed: false`).
- The cross-VLAN firewall rule ([gh#290](https://github.com/SilverDFlame/jellybuntu/issues/290) sub-project 1) is live — k3s can
  reach `192.168.10.18:8200`.
- You have the root token from `bao operator init`, from your password
  manager. Never write it to a file on the VM or paste it into a chat
  session; export it directly into your own shell.
- ESO is **not yet deployed** — this runbook creates the auth backend and
  role ESO's `ClusterSecretStore` will reference. Run this before ESO's
  Helm release lands, or the store will just sit unauthenticated until you
  do.

## 0. Authenticate your session

```bash
ssh ansible@openbao.discus-moth.ts.net
export BAO_ADDR='https://127.0.0.1:8200'
export BAO_SKIP_VERIFY=true
export BAO_TOKEN='<root token from your password manager>'
bao token lookup
```

Confirm the lookup shows the `root` policy before continuing. Without
`BAO_TOKEN` set, every write below fails with `403 permission denied`;
without `BAO_SKIP_VERIFY=true`, every request fails TLS verification
(the server's self-signed cert has no IP SAN for `127.0.0.1`).

## 1. Enable the KV v2 secrets engine

```bash
bao secrets enable -path=secret kv-v2
```

If it's already enabled you'll see `path is already in use at secret/` —
safe to ignore, move on.

## 2. Enable Kubernetes auth

```bash
bao auth enable kubernetes
```

If it's already enabled: `path is already in use at kubernetes/` — safe
to ignore.

Get the k3s CA cert and a reviewer token from a machine with `kubectl`
access to the cluster (not from the OpenBao VM):

```bash
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > /tmp/k3s-ca.pem
head -1 /tmp/k3s-ca.pem  # confirm: -----BEGIN CERTIFICATE-----
kubectl create token default --duration=8760h -n kube-system
```

!!! warning "Cluster name in kubeconfig may not be `default`"
    If `[0]` isn't the right entry (multiple clusters in your kubeconfig),
    run `kubectl config get-clusters` first and target it explicitly:
    `.clusters[?(@.name=="<real-name>")].cluster.certificate-authority-data`.

Copy `/tmp/k3s-ca.pem`'s contents to the OpenBao VM (scp, or paste). Keep
the printed reviewer token in your terminal only — do not save it to a
file.

Write the config as a JSON payload, not individual `key=value` flags:

```bash
cat > /tmp/k8s-auth-config.json <<EOF
{
  "kubernetes_host": "https://k8s-control.discus-moth.ts.net:6443",
  "kubernetes_ca_cert": "$(awk '{printf "%s\\n", $0}' /tmp/k3s-ca.pem)",
  "token_reviewer_jwt": "<paste the kubectl create token output here>"
}
EOF
bao write auth/kubernetes/config @/tmp/k8s-auth-config.json
rm /tmp/k8s-auth-config.json /tmp/k3s-ca.pem
```

!!! warning "Why a JSON payload, not `field=@file` or `field=value` flags"
    Two `bao` CLI quirks, both hit live during this setup:

    1. `kubernetes_ca_cert=@/tmp/k3s-ca.pem` does **not** read the file —
       it silently sends an empty value, and the plugin falls back to the
       in-pod default path (`/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`),
       which doesn't exist on a VM. The `@file` shorthand only works for
       whole-request JSON bodies (`bao write path @file.json`), not
       per-field values.
    2. Passing the PEM directly as `kubernetes_ca_cert="$(cat file)"` on
       the command line breaks the CLI's flag parser: the multiline value
       starts with `-----BEGIN CERTIFICATE-----`, and a leading `-` inside
       an unquoted-by-the-parser positional argument gets misread as a
       flag, dropping the field entirely.

    The JSON-file form sidesteps both.

## 3. Write the ESO read policy

```bash
bao policy write eso-read - <<'EOF'
path "secret/data/jellybuntu/*" {
  capabilities = ["read"]
}
EOF
```

## 4. Bind a Kubernetes auth role to ESO's ServiceAccount

```bash
bao write auth/kubernetes/role/eso \
  bound_service_account_names=external-secrets \
  bound_service_account_namespaces=external-secrets \
  policies=eso-read \
  ttl=1h
```

`external-secrets` (both the SA name and namespace) matches the Helm
release name used in `jellybuntu-helm`'s `HelmRelease` — the chart names
its main ServiceAccount after the release name.

## 5. Verify

```bash
bao read auth/kubernetes/role/eso
```

Expect to see `bound_service_account_names: [external-secrets]` and
`policies: [eso-read]` echoed back.

Confirm the kubernetes auth config landed without printing the CA cert or
reviewer JWT (both public-adjacent but no reason to paste them anywhere):

```bash
bao read -field=kubernetes_host auth/kubernetes/config
bao read -field=kubernetes_ca_cert auth/kubernetes/config | wc -c
bao read auth/kubernetes/config | grep token_reviewer_jwt_set
```

Expect the real host URL, a byte count in the low hundreds to ~2000
(varies with CA key type — k3s's default ECDSA CA runs shorter than an
RSA one), and `token_reviewer_jwt_set    true`. OpenBao never echoes the
JWT itself back on read — it's a write-only field, same as a password —
so `bao read -field=token_reviewer_jwt` correctly reports "not present"
even when it's set.

Once ESO is deployed (see `jellybuntu-helm`), confirm the round trip:

```bash
kubectl get clustersecretstore openbao -o jsonpath='{.status.conditions[0].reason}{"\n"}'
```

Expect `Valid`. If it instead shows a permission-denied or connection
error, re-check the role's `bound_service_account_namespaces` against
ESO's actual deployed namespace, and confirm the firewall rule from
[gh#290](https://github.com/SilverDFlame/jellybuntu/issues/290) sub-project 1 is live.

## KV path convention

Secrets mirror the k3s namespace they're consumed in:
`secret/data/jellybuntu/<namespace>/<service>`, e.g.
`secret/data/jellybuntu/media/postgres`. Established in the
[gh#290 design doc](https://github.com/SilverDFlame/jellybuntu/issues/290);
see that issue for the full migration plan.

## Rotating the Kubernetes auth config

If the k3s API's CA cert or reviewer token ever changes (cluster rebuild,
cert rotation), re-run step 2's `bao write auth/kubernetes/config` with
fresh values. Nothing else in this runbook needs to change.
