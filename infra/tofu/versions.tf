terraform {
  required_version = ">= 1.6.0"

  required_providers {
    b2 = {
      source  = "Backblaze/b2"
      version = "~> 0.10"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}
