variable "account_id" {
  type        = string
  description = "Cloudflare account ID."
  default     = "444c14b123bd021dcdf0400fbd847d63"
}

variable "r2_bucket_name" {
  type        = string
  description = "Existing R2 bucket used by bleeding.fastboop.win."
  default     = "fastboop-bleeding"
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
