provider "github" {
  owner = var.github_owner
}

resource "github_actions_secret" "r2_access_key_id" {
  repository      = var.github_repo
  secret_name     = "R2_ACCESS_KEY_ID"
  plaintext_value = var.r2_access_key_id
}

resource "github_actions_secret" "r2_secret_access_key" {
  repository      = var.github_repo
  secret_name     = "R2_SECRET_ACCESS_KEY"
  plaintext_value = var.r2_secret_access_key
}

resource "github_actions_secret" "r2_bucket" {
  repository      = var.github_repo
  secret_name     = "R2_BUCKET"
  plaintext_value = var.r2_bucket_name
}

resource "github_actions_secret" "r2_endpoint_url" {
  repository      = var.github_repo
  secret_name     = "R2_ENDPOINT_URL"
  plaintext_value = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
}
