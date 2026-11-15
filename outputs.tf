output "service_account_id" {
  description = "ID of the service account GitHub Actions assumes. An identifier, not a secret: store it as a repository variable."
  value       = yandex_iam_service_account.this.id
}

output "federation_id" {
  description = "ID of the federation this module created or reused. Pass it to further identities of the same owner as `existing_federation_id`."
  value       = local.federation_id
}

output "subjects" {
  description = "GitHub OIDC subjects allowed to assume the service account."
  value       = var.subjects
}
