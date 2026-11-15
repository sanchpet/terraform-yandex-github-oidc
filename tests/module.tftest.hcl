mock_provider "yandex" {
  mock_resource "yandex_iam_service_account" {
    defaults = { id = "aje-mock-sa" }
  }
  mock_resource "yandex_iam_workload_identity_oidc_federation" {
    defaults = { id = "aje-mock-federation" }
  }
}

variables {
  folder_id    = "b1g-mock-folder"
  name         = "site-deploy"
  github_owner = "example-org"
  subjects = [
    "repo:example-org/site:ref:refs/heads/main",
    "repo:example-org/site:environment:production",
  ]
  bucket_roles = {
    "site"    = ["storage.uploader"]
    "preview" = ["storage.uploader", "storage.viewer"]
  }
}

run "creates_federation_for_the_owner" {
  command = plan

  assert {
    condition     = length(yandex_iam_workload_identity_oidc_federation.this) == 1
    error_message = "Without existing_federation_id the module must create a federation."
  }

  assert {
    condition     = toset(yandex_iam_workload_identity_oidc_federation.this[0].audiences) == toset(["https://github.com/example-org"])
    error_message = "The audience must be pinned to the owner."
  }

  assert {
    condition     = yandex_iam_workload_identity_oidc_federation.this[0].issuer == "https://token.actions.githubusercontent.com"
    error_message = "The issuer must be GitHub Actions."
  }
}

run "one_credential_per_subject" {
  command = plan

  assert {
    condition     = length(yandex_iam_workload_identity_federated_credential.this) == 2
    error_message = "Each subject needs its own federated credential."
  }

  assert {
    condition     = toset([for c in yandex_iam_workload_identity_federated_credential.this : c.external_subject_id]) == toset(var.subjects)
    error_message = "Credentials must carry exactly the given subjects."
  }
}

run "bucket_roles_fan_out_per_pair" {
  command = plan

  assert {
    condition     = toset(keys(yandex_storage_bucket_iam_binding.this)) == toset(["site/storage.uploader", "preview/storage.uploader", "preview/storage.viewer"])
    error_message = "Each (bucket, role) pair must become one binding."
  }

  assert {
    condition     = length(yandex_resourcemanager_folder_iam_member.this) == 0
    error_message = "No folder roles unless asked for."
  }
}

run "reuses_an_existing_federation" {
  command = apply

  variables {
    existing_federation_id = "aje-shared-federation"
  }

  assert {
    condition     = length(yandex_iam_workload_identity_oidc_federation.this) == 0
    error_message = "With existing_federation_id the module must not create a federation."
  }

  assert {
    condition     = output.federation_id == "aje-shared-federation"
    error_message = "federation_id must report the reused federation."
  }

  assert {
    condition     = alltrue([for c in yandex_iam_workload_identity_federated_credential.this : c.federation_id == "aje-shared-federation"])
    error_message = "Credentials must point at the reused federation."
  }
}

run "rejects_wildcard_subjects" {
  command = plan

  variables {
    subjects = ["repo:example-org/*:ref:refs/heads/main"]
  }

  expect_failures = [var.subjects]
}

run "rejects_empty_subjects" {
  command = plan

  variables {
    subjects = []
  }

  expect_failures = [var.subjects]
}
