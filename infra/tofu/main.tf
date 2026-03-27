provider "b2" {
  application_key_id = var.b2_application_key_id
  application_key    = var.b2_application_key
}

provider "github" {
  owner = var.github_owner
}

provider "kubernetes" {}

data "b2_account_info" "b2" {

}

data "b2_bucket" "rokkitpokkit" {
  bucket_name = var.b2_bucket_name
}

resource "github_actions_secret" "b2_access_key_id" {
  repository      = var.github_repo
  secret_name     = "B2_ACCESS_KEY_ID"
  plaintext_value = var.b2_application_key_id
}

resource "github_actions_secret" "b2_secret_access_key" {
  repository      = var.github_repo
  secret_name     = "B2_SECRET_ACCESS_KEY"
  plaintext_value = var.b2_application_key
}

resource "github_actions_secret" "b2_bucket" {
  repository      = var.github_repo
  secret_name     = "B2_BUCKET"
  plaintext_value = var.b2_bucket_name
}

resource "github_actions_secret" "b2_endpoint_url" {
  repository      = var.github_repo
  secret_name     = "B2_ENDPOINT_URL"
  plaintext_value = data.b2_account_info.b2.s3_api_url
}

resource "github_actions_secret" "b2_public_origin_url" {
  repository      = var.github_repo
  secret_name     = "B2_PUBLIC_ORIGIN_URL"
  plaintext_value = data.b2_account_info.b2.download_url
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

resource "kubernetes_secret" "pmos_storage" {
  metadata {
    name      = "caddy-env"
    namespace = "rokkitpokkit"
  }

  data = {
    B2_PUBLIC_ORIGIN_HOST = trimsuffix(trimprefix(data.b2_account_info.b2.download_url, "https://"), "/")
    B2_BUCKET             = var.b2_bucket_name
  }
}
