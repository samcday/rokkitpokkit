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
  default     = "rokkitpokkit"
}

variable "b2_endpoint_url" {
  type        = string
  description = "S3-compatible endpoint URL for the B2 bucket region."
  default     = "https://s3.us-west-004.backblazeb2.com"
}

variable "b2_public_origin_url" {
  type        = string
  description = "Public B2 download origin URL used by Caddy reverse proxy."
  default     = "https://f000.backblazeb2.com/file/rokkitpokkit"
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

variable "state_passphrase" {
  type        = string
  description = "Passphrase for OpenTofu state encryption (min 16 chars)."
  sensitive   = true
}
