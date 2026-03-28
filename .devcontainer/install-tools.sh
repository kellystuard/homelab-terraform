#!/usr/bin/env bash
set -euo pipefail

# ── OpenTofu ──────────────────────────────────────────────────────────────────
OPENTOFU_VERSION="1.9.0"
curl -fsSL "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_linux_amd64.deb" \
  -o /tmp/opentofu.deb
sudo dpkg -i /tmp/opentofu.deb
rm /tmp/opentofu.deb

# ── tflint ────────────────────────────────────────────────────────────────────
curl -fsSL https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# ── cloudflared ───────────────────────────────────────────────────────────────
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
  | sudo tee /usr/share/keyrings/cloudflare-main.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
  | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt-get update -y && sudo apt-get install -y cloudflared

# ── pre-commit ────────────────────────────────────────────────────────────────
pip install --quiet pre-commit

echo "✅  All tools installed."
echo "   tofu      $(tofu version -json | python3 -c 'import sys,json; print(json.load(sys.stdin)[\"terraform_version\"])')"
echo "   tflint    $(tflint --version)"
echo "   cloudflared $(cloudflared --version)"
echo "   kubectl   $(kubectl version --client --short 2>/dev/null || true)"
