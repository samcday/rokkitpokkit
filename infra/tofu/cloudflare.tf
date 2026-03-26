provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_workers_script" "cdn" {
  account_id = var.cloudflare_account_id
  name       = "rokkitpokkit-cdn"
  content    = file("${path.module}/../worker/worker.js")
  module     = true

  secret_text_binding {
    name = "B2_ACCESS_KEY_ID"
    text = var.b2_application_key_id
  }

  secret_text_binding {
    name = "B2_SECRET_ACCESS_KEY"
    text = var.b2_application_key
  }

  plain_text_binding {
    name = "B2_BUCKET"
    text = var.b2_bucket_name
  }

  plain_text_binding {
    name = "B2_ENDPOINT"
    text = trimprefix(data.b2_account_info.b2.s3_api_url, "https://")
  }
}

resource "cloudflare_workers_domain" "cdn" {
  account_id = var.cloudflare_account_id
  hostname   = "cdn.rokkitpokkit.samcday.com"
  service    = cloudflare_workers_script.cdn.name
  zone_id    = var.cloudflare_zone_id
}
