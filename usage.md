# Using kubectl with the Homelab Kubernetes API

The Kubernetes API on `redtrim.local` is exposed through the public hostname `<k8s-public-hostname>`
via a Cloudflare Tunnel and protected by Cloudflare Access using a Service Token.

Retrieve the public hostname from the Terraform output:

```bash
export K8S_HOSTNAME="$(tofu output -raw k8s_hostname)"
```

## Prerequisites

| Tool | Install |
|------|---------|
| `kubectl` | <https://kubernetes.io/docs/tasks/tools/> |
| `cloudflared` | <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/> |

## Retrieve the service token credentials

After running `tofu apply`, retrieve the sensitive outputs:

```bash
# Client ID (not sensitive – safe to display)
tofu output service_token_client_id

# Client Secret (sensitive – stored securely)
tofu output -raw service_token_client_secret
```

Export both values as environment variables for the steps below:

```bash
export CF_CLIENT_ID="$(tofu output -raw service_token_client_id)"
export CF_CLIENT_SECRET="$(tofu output -raw service_token_client_secret)"
```

## Run the cloudflared local proxy

`cloudflared` opens a local TCP tunnel that forwards traffic through Cloudflare
Access using the service token.  Run this in a dedicated terminal or as a
background service:

```bash
cloudflared access tcp \
  --hostname "$K8S_HOSTNAME" \
  --url 127.0.0.1:6443 \
  --service-token-id     "$CF_CLIENT_ID" \
  --service-token-secret "$CF_CLIENT_SECRET"
```

> **Tip – run as a background service**
> ```bash
> CF_ACCESS_CLIENT_ID="$CF_CLIENT_ID" \
> CF_ACCESS_CLIENT_SECRET="$CF_CLIENT_SECRET" \
> cloudflared access tcp \
>   --hostname "$K8S_HOSTNAME" \
>   --url 127.0.0.1:6443 &
> ```

## Configure kubectl

Add (or update) a cluster entry pointing at the local proxy:

```bash
kubectl config set-cluster homelab \
  --server=https://127.0.0.1:6443 \
  --insecure-skip-tls-verify=true

kubectl config set-credentials homelab-admin \
  --token="$(kubectl --kubeconfig /path/to/redtrim-admin.kubeconfig \
              config view --raw --minify \
              -o jsonpath='{.users[0].user.token}')"

kubectl config set-context homelab \
  --cluster=homelab \
  --user=homelab-admin

kubectl config use-context homelab
```

> If you already have a kubeconfig from `redtrim.local`, you can merge it:
> ```bash
> KUBECONFIG=~/.kube/config:/path/to/redtrim-admin.kubeconfig \
>   kubectl config view --flatten > ~/.kube/config
> ```
> Then edit `~/.kube/config` and update the server URL for the `homelab` cluster
> to `https://127.0.0.1:6443`.

## Use kubectl

With the `cloudflared` proxy running:

```bash
# Check cluster connectivity
kubectl cluster-info

# List nodes
kubectl get nodes

# List all pods across namespaces
kubectl get pods --all-namespaces
```

## Setting up cloudflared on redtrim.local

Retrieve the tunnel token and run `cloudflared` on `redtrim.local`:

```bash
# On the workstation running tofu
tofu output -raw tunnel_token
```

On `redtrim.local`:

```bash
# Install cloudflared
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
  | sudo tee /usr/share/keyrings/cloudflare-main.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] \
  https://pkg.cloudflare.com/cloudflared any main" \
  | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt-get update && sudo apt-get install -y cloudflared

# Install and start the tunnel as a systemd service
sudo cloudflared service install <tunnel_token>
sudo systemctl enable --now cloudflared
```
