# Random secret used to register the cloudflared tunnel with Cloudflare
resource "random_id" "tunnel_secret" {
  byte_length = 32
}

# Cloudflare Tunnel that cloudflared runs on redtrim.local
resource "cloudflare_tunnel" "k8s" {
  account_id = var.cloudflare_account_id
  name       = "homelab-k8s"
  secret     = random_id.tunnel_secret.b64_std
}

# Tunnel ingress: route the cfargotunnel.com endpoint → the Kubernetes API on redtrim.local
resource "cloudflare_tunnel_config" "k8s" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.k8s.id

  config {
    ingress_rule {
      hostname = "${cloudflare_tunnel.k8s.id}.cfargotunnel.com"
      service  = "https://redtrim.local:6443"

      origin_request {
        # redtrim.local likely uses a self-signed certificate
        no_tls_verify = true
      }
    }

    # Catch-all rule required by Cloudflare
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# Cloudflare Access Application protecting the Kubernetes API endpoint
resource "cloudflare_access_application" "k8s" {
  account_id       = var.cloudflare_account_id
  name             = "Homelab Kubernetes API"
  domain           = "${cloudflare_tunnel.k8s.id}.cfargotunnel.com"
  session_duration = "24h"
  type             = "self_hosted"
}

# Service Token for non-interactive / programmatic kubectl access
resource "cloudflare_access_service_token" "k8s" {
  account_id           = var.cloudflare_account_id
  name                 = "homelab-k8s-service-token"
  min_days_for_renewal = 30
}

# Access Policy: allow the service token to reach the Kubernetes API
resource "cloudflare_access_policy" "k8s_service_token" {
  application_id = cloudflare_access_application.k8s.id
  account_id     = var.cloudflare_account_id
  name           = "Allow Service Token"
  precedence     = 1
  decision       = "non_identity"

  include {
    service_token = [cloudflare_access_service_token.k8s.id]
  }
}
