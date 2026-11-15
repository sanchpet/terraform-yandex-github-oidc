provider "yandex" {
  # Credentials and cloud from the environment: YC_TOKEN, YC_CLOUD_ID.
  folder_id = var.folder_id
}

variable "folder_id" {
  type = string
}

resource "yandex_storage_bucket" "site" {
  bucket    = "example-site-bucket"
  folder_id = var.folder_id
}

# The production deploy creates the federation for the owner.
module "site_deploy" {
  source = "../.."

  folder_id    = var.folder_id
  name         = "example-site-deploy"
  github_owner = "example-org"
  description  = "Deploys example-org/site from main"

  subjects = ["repo:example-org/site:ref:refs/heads/main"]

  bucket_roles = {
    (yandex_storage_bucket.site.bucket) = ["storage.uploader"]
  }
}

resource "yandex_storage_bucket" "preview" {
  bucket    = "example-preview-bucket"
  folder_id = var.folder_id
}

# A second identity of the same owner reuses that federation.
module "preview_deploy" {
  source = "../.."

  folder_id              = var.folder_id
  name                   = "example-preview-deploy"
  github_owner           = "example-org"
  existing_federation_id = module.site_deploy.federation_id

  subjects = ["repo:example-org/site:environment:preview"]

  bucket_roles = {
    (yandex_storage_bucket.preview.bucket) = ["storage.uploader"]
  }
}

output "site_service_account_id" {
  value = module.site_deploy.service_account_id
}
