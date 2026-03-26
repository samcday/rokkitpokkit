variable "b2_application_key_id" {
  type        = string
  description = "Backblaze B2 primary application key ID used by the b2 provider."
  sensitive   = true
}

variable "b2_application_key" {
  type        = string
  description = "Backblaze B2 primary application key used by the b2 provider."
  sensitive   = true
}

variable "b2_bucket_name" {
  type        = string
  description = "Backblaze B2 bucket name for published artifacts."
}

variable "cloudflare_api_token" {
  type        = string
  description = "Cloudflare API token with Workers and DNS permissions."
  sensitive   = true
}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare account ID."
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Cloudflare zone ID for samcday.com."
}

variable "github_owner" {
  type        = string
  description = "GitHub repository owner."
  default     = "samcday"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name."
  default     = "rokkitpokkit"
}
