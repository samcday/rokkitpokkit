provider "b2" {
  application_key_id = var.b2_application_key_id
  application_key    = var.b2_application_key
}

provider "github" {
  owner = var.github_owner
}

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
