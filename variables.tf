variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the public hostname used to reach the Kubernetes API"
  type        = string
}

variable "k8s_public_hostname" {
  description = "Public DNS hostname in your Cloudflare-managed zone for the Kubernetes API (for example: k8s.example.com)"
  type        = string
}
