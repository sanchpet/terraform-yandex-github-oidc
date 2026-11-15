# terraform-yandex-github-oidc — instructions for Claude Code

Public Terraform module: a Yandex Cloud service account that GitHub Actions assumes over OIDC. Published to the Terraform Registry; consumers pin it by version or git tag.

## Rules

- **Public repo.** No real cloud, folder, account or federation IDs, no hostnames, no references to private repositories. Examples use `example-org` and placeholder IDs.
- **Inputs are a contract.** Renaming or retyping a variable, or a change that recreates the service account or the federation, breaks consumers on their next apply. A recreated service account gets a new ID, and every workflow holding the old one stops authenticating. Treat it as a breaking change and say so in the PR.
- The module configures no provider. Consumers do.
- English for all repo artifacts, `--signoff` on every commit.
- **Conventional Commits + release-please.** PRs are squash-merged and the PR title is the release commit (CI checks it). Never tag or edit `CHANGELOG.md` by hand; merge the release PR. Release PRs opened by `GITHUB_TOKEN` get no CI run, so run the checks locally before merging one.
- Branch + PR.

## Checks

```sh
mise install
terraform fmt -check -recursive && terraform init -backend=false && terraform validate
terraform test
tflint --init && tflint
terraform-docs .
```
