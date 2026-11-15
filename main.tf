locals {
  issuer = "https://token.actions.githubusercontent.com"

  # GitHub mints the token for whatever audience the workflow asks for. Pinning it to the owner keeps
  # a token issued for somebody else's account from being accepted here.
  audiences = ["https://github.com/${var.github_owner}"]

  create_federation = var.existing_federation_id == null
  federation_id     = local.create_federation ? yandex_iam_workload_identity_oidc_federation.this[0].id : var.existing_federation_id

  bucket_bindings = {
    for pair in flatten([
      for bucket, roles in var.bucket_roles : [
        for role in roles : { key = "${bucket}/${role}", bucket = bucket, role = role }
      ]
    ]) : pair.key => pair
  }
}

resource "yandex_iam_service_account" "this" {
  folder_id   = var.folder_id
  name        = var.name
  description = var.description
}

resource "yandex_resourcemanager_folder_iam_member" "this" {
  for_each = toset(var.folder_roles)

  folder_id = var.folder_id
  role      = each.value
  member    = "serviceAccount:${yandex_iam_service_account.this.id}"
}

resource "yandex_storage_bucket_iam_binding" "this" {
  for_each = local.bucket_bindings

  bucket  = each.value.bucket
  role    = each.value.role
  members = ["serviceAccount:${yandex_iam_service_account.this.id}"]
}

resource "yandex_iam_workload_identity_oidc_federation" "this" {
  count = local.create_federation ? 1 : 0

  folder_id   = var.folder_id
  name        = var.name
  description = var.description
  labels      = var.labels
  issuer      = local.issuer
  jwks_url    = "${local.issuer}/.well-known/jwks"
  audiences   = local.audiences
}

resource "yandex_iam_workload_identity_federated_credential" "this" {
  for_each = toset(var.subjects)

  service_account_id  = yandex_iam_service_account.this.id
  federation_id       = local.federation_id
  external_subject_id = each.value
}
