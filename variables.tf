variable "cloudflare_api_token" {
  description = "Cloudflare API token with permissions: Zone:Read, DNS:Edit, Argo Tunnel:Edit, Access:Edit"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for the stuard.us domain"
  type        = string
}
