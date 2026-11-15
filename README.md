# terraform-yandex-github-oidc

Terraform module that lets a GitHub Actions workflow act in Yandex Cloud without a stored key. For anyone who deploys from GitHub into Yandex Cloud and keeps a static access key in repository secrets.

The workflow asks GitHub for a short-lived OIDC token. Yandex Cloud checks its signature, audience and `sub` claim through workload identity federation and returns an IAM token for a service account. Nothing long-lived exists on either side.

The module creates:

- a service account, with roles on individual buckets (`bucket_roles`) and, if you must, on the folder (`folder_roles`);
- a workload identity federation that trusts GitHub tokens issued for one owner, or reuses an existing one;
- one federated credential per allowed `sub`.

## Usage

```hcl
module "site_deploy" {
  source  = "sanchpet/github-oidc/yandex"
  version = "~> 0.1"

  folder_id    = "<folder-id>"
  name         = "site-deploy"
  github_owner = "example-org"

  subjects = ["repo:example-org/site:ref:refs/heads/main"]

  bucket_roles = {
    "example-site-bucket" = ["storage.uploader"]
  }
}
```

A second identity of the same owner reuses the federation: pass `existing_federation_id = module.site_deploy.federation_id`. One federation per owner is enough, identities differ only in subjects and roles. See [`examples/basic`](examples/basic).

The module configures no provider. Configure `yandex` in the calling configuration.

On the GitHub side the job needs `id-token: write`, and the service account ID goes in as a repository variable, not a secret: it is useless without a token whose `sub` is allowed. With an action from [yc-actions](https://github.com/yc-actions) that takes `yc-sa-id`:

```yaml
permissions:
  contents: read
  id-token: write

steps:
  - uses: yc-actions/yc-obj-storage-upload@v4
    with:
      yc-sa-id: ${{ vars.YC_DEPLOY_SA_ID }}
      bucket: example-site-bucket
      root: ./dist
      include: '**'
```

## Writing `subjects`

`subjects` is the actual control. GitHub mints a token for any workflow in the repository; the `sub` claim tells a push to `main` from a pull request or a fork. Matching is exact and has no wildcard, so the module rejects `*`.

Read the real claim before writing it:

```sh
gh api repos/<owner>/<repo>/actions/oidc/customization/sub
```

Many repositories now get the immutable form with numeric IDs, `repo:<owner>@<owner-id>/<repo>@<repo-id>:ref:refs/heads/main`. It keeps naming the same repository after a rename. Use it where GitHub issues it, and do not also allow the readable form as a fallback: a renamed owner leaves the old name free for someone else to register, and their workflow would present a subject you trust.

Common shapes:

| Workflow | `sub` |
|---|---|
| push to a branch | `repo:<owner>/<repo>:ref:refs/heads/<branch>` |
| job with an environment | `repo:<owner>/<repo>:environment:<name>` |
| pull request | `repo:<owner>/<repo>:pull_request` |

## Choosing roles

Prefer `bucket_roles`. A runner executes code that can arrive in a pull request, so treat the identity as reachable by anyone who can open one. A folder role hands them every bucket in the folder.

`storage.uploader` writes objects without reading any, which is enough for a deploy that uploads files. Actions that list the bucket first, to delete stale objects or skip unchanged ones, need read access too.

`yandex_storage_bucket_iam_binding` is authoritative for each (bucket, role) pair: it replaces any other members of that pair. Two configurations that bind the same role on the same bucket overwrite each other.

## When the exchange fails

The token exchange answers HTTP 401 and does not say which claim disagreed. Check in this order:

1. The job has `id-token: write`.
2. The `sub` from the `gh api` call above is in `subjects`, character for character.
3. The repository variable holds the current `service_account_id`. A recreated service account has a new ID.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_yandex"></a> [yandex](#requirement\_yandex) | >= 0.221 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_yandex"></a> [yandex](#provider\_yandex) | >= 0.221 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [yandex_iam_service_account.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/iam_service_account) | resource |
| [yandex_iam_workload_identity_federated_credential.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/iam_workload_identity_federated_credential) | resource |
| [yandex_iam_workload_identity_oidc_federation.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/iam_workload_identity_oidc_federation) | resource |
| [yandex_resourcemanager_folder_iam_member.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/resourcemanager_folder_iam_member) | resource |
| [yandex_storage_bucket_iam_binding.this](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/storage_bucket_iam_binding) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_folder_id"></a> [folder\_id](#input\_folder\_id) | Folder the federation, the service account and its folder roles live in. | `string` | n/a | yes |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub user or organization that owns the repositories. The federation accepts only tokens issued for the audience `https://github.com/<owner>`. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the service account, and of the federation when this module creates one. Usually the repository it serves. | `string` | n/a | yes |
| <a name="input_subjects"></a> [subjects](#input\_subjects) | GitHub OIDC `sub` claims allowed to assume the service account. Matching is exact, there is no wildcard. Read the real form with `gh api repos/<owner>/<repo>/actions/oidc/customization/sub` before writing it: many repositories get the immutable form with numeric IDs. See the README. | `list(string)` | n/a | yes |
| <a name="input_bucket_roles"></a> [bucket\_roles](#input\_bucket\_roles) | Roles on individual buckets, keyed by bucket name. The right scope for a deploy identity. The binding is authoritative for each (bucket, role) pair: it replaces any other members of that pair. | `map(list(string))` | `{}` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the service account and the federation. | `string` | `""` | no |
| <a name="input_existing_federation_id"></a> [existing\_federation\_id](#input\_existing\_federation\_id) | Reuse a federation instead of creating one. A federation only states that Yandex Cloud trusts GitHub tokens for this owner, so one per owner is enough: further identities pass its ID here and differ only in subjects and roles. Null creates a federation. | `string` | `null` | no |
| <a name="input_folder_roles"></a> [folder\_roles](#input\_folder\_roles) | Roles on the whole folder. Keep it empty unless a role has no bucket-level equivalent: a runner executes code that can arrive in a pull request. | `list(string)` | `[]` | no |
| <a name="input_labels"></a> [labels](#input\_labels) | Labels of the federation. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_federation_id"></a> [federation\_id](#output\_federation\_id) | ID of the federation this module created or reused. Pass it to further identities of the same owner as `existing_federation_id`. |
| <a name="output_service_account_id"></a> [service\_account\_id](#output\_service\_account\_id) | ID of the service account GitHub Actions assumes. An identifier, not a secret: store it as a repository variable. |
| <a name="output_subjects"></a> [subjects](#output\_subjects) | GitHub OIDC subjects allowed to assume the service account. |
<!-- END_TF_DOCS -->

## License

MIT
