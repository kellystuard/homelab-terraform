# Using kubectl with the Homelab Kubernetes API

The Kubernetes API on `redtrim.local` is exposed publicly at `https://homelab.stuard.us`
via a Cloudflare Tunnel and protected by Cloudflare Access using a Service Token.

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
  --hostname homelab.stuard.us \
  --url 127.0.0.1:6443 \
  --service-token-id     "$CF_CLIENT_ID" \
  --service-token-secret "$CF_CLIENT_SECRET"
```

> **Tip – run as a background service**
> ```bash
> CF_ACCESS_CLIENT_ID="$CF_CLIENT_ID" \
> CF_ACCESS_CLIENT_SECRET="$CF_CLIENT_SECRET" \
> cloudflared access tcp \
>   --hostname homelab.stuard.us \
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

## Passing the service token directly in every kubectl call

If you prefer not to run `cloudflared` as a proxy, you can pass the Cloudflare
Access headers in each request via a `kubeconfig` exec credential plugin.

Create the file `~/.kube/cf-token-plugin.sh`:

```bash
#!/usr/bin/env bash
# Exchanges the Cloudflare service token for a short-lived JWT
# and returns it in the ExecCredential format expected by kubectl.
set -euo pipefail

TOKEN=$(curl -fsSL \
  -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
  "https://homelab.stuard.us/cdn-cgi/access/get-identity" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('token',''))")

cat <<EOF
{
  "apiVersion": "client.authentication.k8s.io/v1",
  "kind": "ExecCredential",
  "status": {
    "token": "$TOKEN"
  }
}
EOF
```

```bash
chmod +x ~/.kube/cf-token-plugin.sh
```

Reference the plugin in `~/.kube/config`:

```yaml
users:
- name: homelab-cf
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1
      command: /home/<you>/.kube/cf-token-plugin.sh
      env:
      - name: CF_ACCESS_CLIENT_ID
        value: "<client_id>"
      - name: CF_ACCESS_CLIENT_SECRET
        value: "<client_secret>"
      interactiveMode: Never
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
