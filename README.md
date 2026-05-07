# homelab-terraform

Personal homelab OpenTofu configuration for exposing the Kubernetes API on `redtrim.local` through a **Cloudflare Tunnel** and protecting it with **Cloudflare Access** using a **service token**.

This repository is a **standalone** OpenTofu root configuration. It provisions the Cloudflare-side resources needed to make the cluster reachable at a public hostname in your **Cloudflare-managed zone**, then emits the credentials and tokens needed to finish the setup.

---

## Overview

This configuration creates:

- a Cloudflare Tunnel named `homelab-k8s`
- tunnel configuration routing TCP traffic to `localhost:6443`
- a proxied Cloudflare DNS record for your public Kubernetes hostname
- a Cloudflare Access application for the Kubernetes API
- a Cloudflare Access service token for non-interactive access
- an Access policy that allows that service token to reach the endpoint

The public hostname is exposed as:

```text
<k8s-public-hostname>
```

For example:

```text
k8s.example.com
```

---

## What This Repo Does

After `tofu apply`, you will have:

1. A Cloudflare Tunnel configured for the Kubernetes API on `redtrim.local`
2. A service token you can use with `cloudflared` and `kubectl`
3. Outputs for:
   - the public hostname
   - the tunnel ID
   - the tunnel token
   - the Cloudflare Access client ID
   - the Cloudflare Access client secret

---

## What This Repo Does **Not** Do

To stay accurate to the code in this repository, this project does **not** currently:

- install `cloudflared` on `redtrim.local`
- create or manage the Kubernetes cluster itself
- manage multiple public hostnames or wildcard routes beyond the single configured Kubernetes endpoint
- replace the fixed host/port values (`redtrim.local` and `6443`)

---

## Requirements

### Tools

- `OpenTofu` `>= 1.6`
- `cloudflared` for tunnel runtime and local access proxying
- `kubectl` for Kubernetes access
- `pre-commit` for local validation and secret scanning

### Cloudflare

You need:

- a Cloudflare account ID
- a Cloudflare zone ID for the public DNS record
- a public hostname in that zone for the Kubernetes API (for example `k8s.example.com`)
- a Cloudflare API token with these permissions:

  **Zone permissions** (scoped to the zone you are managing):
  - `Zone:Read`
  - `DNS:Edit`

  **Account permissions** (scoped to your Cloudflare account):
  - `Cloudflare Tunnel:Edit`
  - `Access: Apps and Policies:Edit`
  - `Access: Service Tokens:Edit`

### Environment Assumptions

This repo assumes all of the following are already true:

- `redtrim.local` is the machine that can reach the Kubernetes API locally
- the Kubernetes API is available at `redtrim.local:6443`
- `cloudflared` will be installed and run on `redtrim.local`

---

## Inputs

This configuration reads credentials from environment variables:

| Environment Variable | Description | Sensitive |
|---|---|---:|
| `CLOUDFLARE_API_TOKEN` | Cloudflare API token with Tunnel, Access Apps/Policies, Service Tokens, and DNS permissions | Yes |
| `TF_VAR_cloudflare_account_id` | Cloudflare account ID (populates `var.cloudflare_account_id`) | No |
| `TF_VAR_cloudflare_zone_id` | Cloudflare zone ID for the public DNS record | No |
| `TF_VAR_k8s_public_hostname` | Public hostname to expose the Kubernetes API (for example `k8s.example.com`) | No |

---

## Using This Repo in Spacelift

This repository already contains the OpenTofu files needed to run the stack:

- `providers.tf`
- `main.tf`
- `variables.tf`
- `outputs.tf`

### Spacelift environment variables

Set these stack environment variables:

```bash
CLOUDFLARE_API_TOKEN=<your_cloudflare_api_token>
TF_VAR_cloudflare_account_id=<your_cloudflare_account_id>
TF_VAR_cloudflare_zone_id=<your_cloudflare_zone_id>
TF_VAR_k8s_public_hostname=k8s.example.com
```

Recommended handling:

- mark `CLOUDFLARE_API_TOKEN` as **sensitive / masked**
- keep `TF_VAR_cloudflare_account_id`, `TF_VAR_cloudflare_zone_id`, and `TF_VAR_k8s_public_hostname` as normal plain-text variables

If you run this outside Spacelift, export the same environment variables in your shell before running `tofu plan` / `tofu apply`.

---

## Local Usage

### 0. Enable the git hooks

```bash
pre-commit install
pre-commit run --all-files
```

This runs the standard repo checks plus secret scanning before commits.

### 1. Initialize

```bash
tofu init
```

### 2. Preview changes

```bash
export CLOUDFLARE_API_TOKEN=<your_api_token>
export TF_VAR_cloudflare_account_id=<your_account_id>
export TF_VAR_cloudflare_zone_id=<your_zone_id>
export TF_VAR_k8s_public_hostname=k8s.example.com
tofu plan
```

### 3. Apply

```bash
tofu apply
```

---

## Outputs

After apply, this repo exposes the following outputs:

| Output | Description |
|---|---|
| `k8s_endpoint` | Public hostname for the Kubernetes API via Cloudflare Tunnel and Access |
| `k8s_hostname` | Public DNS hostname for the Kubernetes API |
| `service_token_client_id` | Cloudflare Access client ID header value |
| `service_token_client_secret` | Cloudflare Access client secret header value |
| `tunnel_id` | Tunnel ID for configuration and access workflows |
| `tunnel_token` | Tunnel token used to run `cloudflared` on `redtrim.local` |

Examples:

```bash
tofu output k8s_endpoint
tofu output -raw k8s_hostname
tofu output -raw tunnel_id
tofu output -raw service_token_client_id
tofu output -raw service_token_client_secret
tofu output -raw tunnel_token
```

> Treat `service_token_client_secret` and `tunnel_token` as secrets.

---

## Finish Setup on `redtrim.local`

Once the Cloudflare-side resources exist, install and run `cloudflared` on `redtrim.local`.

### 1. Get the tunnel token

From the machine where you ran OpenTofu:

```bash
tofu output -raw tunnel_token
```

### 2. Install `cloudflared`

On `redtrim.local`:

```bash
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
  | sudo tee /usr/share/keyrings/cloudflare-main.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] \
  https://pkg.cloudflare.com/cloudflared any main" \
  | sudo tee /etc/apt/sources.list.d/cloudflared.list

sudo apt-get update
sudo apt-get install -y cloudflared
```

### 3. Install the tunnel as a service

```bash
sudo cloudflared service install <tunnel_token>
sudo systemctl enable --now cloudflared
```

---

## Access the Cluster from a Workstation

### 1. Export the generated values

```bash
export K8S_HOSTNAME="$(tofu output -raw k8s_hostname)"
export CF_CLIENT_ID="$(tofu output -raw service_token_client_id)"
export CF_CLIENT_SECRET="$(tofu output -raw service_token_client_secret)"
```

### 2. Start a local `cloudflared` TCP proxy

```bash
cloudflared access tcp \
  --hostname "$K8S_HOSTNAME" \
  --url 127.0.0.1:6443 \
  --service-token-id "$CF_CLIENT_ID" \
  --service-token-secret "$CF_CLIENT_SECRET"
```

This forwards your local `127.0.0.1:6443` through Cloudflare Access to the Kubernetes API behind the tunnel.

### 3. Point `kubectl` at the local proxy

```bash
kubectl config set-cluster homelab \
  --server=https://127.0.0.1:6443 \
  --insecure-skip-tls-verify=true
```

If you already have an admin kubeconfig from `redtrim.local`, you can use it to set credentials and context as needed.

Typical checks:

```bash
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces
```

---

## Security Notes

- `service_token_client_secret` is sensitive and should be stored securely.
- `tunnel_token` grants the ability to run the tunnel and should also be treated as sensitive.
- The Access policy in this repo is configured for **service token** access rather than interactive user identity.
- Tunnel ingress is configured in TCP mode (`tcp://localhost:6443`) for compatibility with Cloudflare Free when used with `cloudflared access tcp`.

---

## Repository Structure

```text
.
├── main.tf
├── outputs.tf
├── providers.tf
├── README.md
└── variables.tf
```

---

## Notes and Caveats

These points are directly based on the current code:

- the tunnel name is fixed to `homelab-k8s`
- the origin is fixed to `tcp://localhost:6443`
- the public hostname is provided via `var.k8s_public_hostname` and created as a proxied CNAME to the tunnel
- this is a personal homelab-oriented setup, not a generalized module

If you want this repo to become more reusable later, the next natural improvements would be:

- parameterize the origin hostname and port
- optionally support a custom domain
- optionally support identity-based Access policies in addition to service tokens
- document or automate the `cloudflared` host-side installation path further

---

## Contributing

This is a personal homelab repository. Small cleanups are easy to make, but the current configuration is intentionally opinionated and host-specific.

---

## License

No license file is currently present in this repository.
