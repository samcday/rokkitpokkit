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
