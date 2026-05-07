# Random secret used to register the cloudflared tunnel with Cloudflare
resource "random_id" "tunnel_secret" {
  byte_length = 32
}

# Cloudflare Tunnel that cloudflared runs on redtrim.local
resource "cloudflare_zero_trust_tunnel_cloudflared" "k8s" {
  account_id    = var.cloudflare_account_id
  name          = "homelab-k8s"
  tunnel_secret = random_id.tunnel_secret.b64_std
}

# Tunnel ingress: route the public hostname to the Kubernetes API over TCP
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "k8s" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.k8s.id

  config = {
    ingress = [
      {
        hostname = var.k8s_public_hostname
        service  = "tcp://localhost:6443"
      },

      # Catch-all rule required by Cloudflare
      {
        service = "http_status:404"
      },
    ]
  }
}

# Public DNS hostname in a Cloudflare-managed zone -> tunnel UUID target
resource "cloudflare_dns_record" "k8s" {
  zone_id = var.cloudflare_zone_id
  name    = var.k8s_public_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.k8s.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

# Cloudflare Access Application protecting the Kubernetes API endpoint
resource "cloudflare_zero_trust_access_application" "k8s" {
  account_id       = var.cloudflare_account_id
  name             = "Homelab Kubernetes API"
  domain           = var.k8s_public_hostname
  session_duration = "24h"
  type             = "self_hosted"

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.k8s_service_token.id
      precedence = 1
    },
  ]
}

# Service Token for non-interactive / programmatic kubectl access
resource "cloudflare_zero_trust_access_service_token" "k8s" {
  account_id = var.cloudflare_account_id
  name       = "homelab-k8s-service-token"
}

# Access Policy: allow the service token to reach the Kubernetes API
resource "cloudflare_zero_trust_access_policy" "k8s_service_token" {
  account_id = var.cloudflare_account_id
  name       = "Allow Service Token"
  decision   = "non_identity"

  include = [
    {
      service_token = {
        token_id = cloudflare_zero_trust_access_service_token.k8s.id
      }
    },
  ]
}
