provider "cloudflare" {
}

provider "github" {
  owner = var.github_owner
}

data "cloudflare_api_token_permission_groups_list" "r2_bucket_item_write" {
  name = "Workers R2 Storage Bucket Item Write"
}

data "cloudflare_api_token_permission_groups_list" "r2_storage_write" {
  name = "Workers R2 Storage Write"
}

locals {
  r2_bucket_item_write_permission_group_id = coalesce(
    try(one(data.cloudflare_api_token_permission_groups_list.r2_bucket_item_write.result).id, null),
    try(one(data.cloudflare_api_token_permission_groups_list.r2_storage_write.result).id, null)
  )
  r2_bucket_resource = "com.cloudflare.edge.r2.bucket.${var.account_id}_default_${var.r2_bucket_name}"
}

resource "cloudflare_api_token" "rokkitpokkit_upload" {
  name = "rokkitpokkit-r2-upload"

  lifecycle {
    precondition {
      condition     = local.r2_bucket_item_write_permission_group_id != null
      error_message = "Could not resolve an R2 write permission group from Cloudflare."
    }
  }

  policies = [{
    effect = "allow"
    permission_groups = [{
      id = local.r2_bucket_item_write_permission_group_id
    }]
    resources = jsonencode({
      (local.r2_bucket_resource) = "*"
    })
  }]
}

resource "github_actions_secret" "r2_access_key_id" {
  repository      = var.github_repo
  secret_name     = "R2_ACCESS_KEY_ID"
  plaintext_value = cloudflare_api_token.rokkitpokkit_upload.id
}

resource "github_actions_secret" "r2_secret_access_key" {
  repository      = var.github_repo
  secret_name     = "R2_SECRET_ACCESS_KEY"
  plaintext_value = sha256(cloudflare_api_token.rokkitpokkit_upload.value)
}

resource "github_actions_secret" "r2_bucket" {
  repository      = var.github_repo
  secret_name     = "R2_BUCKET"
  plaintext_value = var.r2_bucket_name
}

resource "github_actions_secret" "r2_endpoint_url" {
  repository      = var.github_repo
  secret_name     = "R2_ENDPOINT_URL"
  plaintext_value = "https://${var.account_id}.r2.cloudflarestorage.com"
}

resource "github_actions_secret" "tofu_state_passphrase" {
  repository      = var.github_repo
  secret_name     = "TF_VAR_state_passphrase"
  plaintext_value = var.state_passphrase
}
