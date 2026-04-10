output "k8s_endpoint" {
  description = "Public HTTPS endpoint for the Kubernetes API (via Cloudflare Tunnel and Access)"
  value       = "https://${var.k8s_public_hostname}"
}

output "k8s_hostname" {
  description = "Public DNS hostname for the Kubernetes API"
  value       = var.k8s_public_hostname
}

output "service_token_client_id" {
  description = "CF-Access-Client-Id header value for kubectl authentication"
  value       = cloudflare_zero_trust_access_service_token.k8s.client_id
}

output "service_token_client_secret" {
  description = "CF-Access-Client-Secret header value for kubectl authentication"
  value       = cloudflare_zero_trust_access_service_token.k8s.client_secret
  sensitive   = true
}

output "tunnel_id" {
  description = "Cloudflare Tunnel ID – used to configure cloudflared on redtrim.local"
  value       = cloudflare_zero_trust_tunnel_cloudflared.k8s.id
}

output "tunnel_token" {
  description = "Cloudflare Tunnel token – pass to `cloudflared tunnel run --token <value>` on redtrim.local"
  value = base64encode(jsonencode({
    a = cloudflare_zero_trust_tunnel_cloudflared.k8s.account_tag
    t = cloudflare_zero_trust_tunnel_cloudflared.k8s.id
    s = random_id.tunnel_secret.b64_std
  }))
  sensitive = true
}
