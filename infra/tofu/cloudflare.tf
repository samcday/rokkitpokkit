provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_workers_script" "cdn" {
  account_id = var.cloudflare_account_id
  name       = "rokkitpokkit-cdn"
  content    = file("${path.module}/../worker/worker.js")
  module     = true

  r2_bucket_binding {
    name        = "BUCKET"
    bucket_name = var.r2_bucket_name
  }
}

resource "cloudflare_workers_domain" "cdn" {
  account_id = var.cloudflare_account_id
  hostname   = "cdn.rokkitpokkit.samcday.com"
  service    = cloudflare_workers_script.cdn.name
  zone_id    = var.cloudflare_zone_id
}
