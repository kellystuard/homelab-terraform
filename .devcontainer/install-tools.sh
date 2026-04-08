#!/usr/bin/env bash
set -euo pipefail

# ── cloudflared ───────────────────────────────────────────────────────────────
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
  | sudo tee /usr/share/keyrings/cloudflare-main.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
  | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt-get update -y && sudo apt-get install -y cloudflared

# ── pre-commit ────────────────────────────────────────────────────────────────
pip install --quiet pre-commit

tool_version() {
  local name="$1"
  local cmd="$2"

  if command -v "$name" >/dev/null 2>&1; then
    # Keep each command isolated so one failing version check doesn't stop output.
    local out
    out="$(bash -lc "$cmd" 2>/dev/null || true)"
    if [[ -n "$out" ]]; then
      printf "  ℹ️  %-11s  %s\n" "${name}" "${out}"
    else
      printf "  ℹ️  %-11s  installed (version unavailable)\n" "${name}"
    fi
  else
    printf "  ℹ️  %-11s  not installed\n" "${name}"
  fi
}

echo "✅ All tools installed."
tool_version "tofu" "tofu version -json | jq -r '.terraform_version'"
tool_version "cloudflared" "cloudflared version --short"
tool_version "kubectl" "kubectl version --client=true -o json | jq -r '.clientVersion.gitVersion'"
tool_version "helm" "helm version --short"
tool_version "pre-commit" "pre-commit --version | sed 's/^.*pre-commit //'"
