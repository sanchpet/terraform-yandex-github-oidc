variable "folder_id" {
  description = "Folder the federation, the service account and its folder roles live in."
  type        = string
}

variable "name" {
  description = "Name of the service account, and of the federation when this module creates one. Usually the repository it serves."
  type        = string
}

variable "github_owner" {
  description = "GitHub user or organization that owns the repositories. The federation accepts only tokens issued for the audience `https://github.com/<owner>`."
  type        = string

  validation {
    condition     = length(trimspace(var.github_owner)) > 0
    error_message = "github_owner must not be empty."
  }
}

variable "subjects" {
  description = "GitHub OIDC `sub` claims allowed to assume the service account. Matching is exact, there is no wildcard. Read the real form with `gh api repos/<owner>/<repo>/actions/oidc/customization/sub` before writing it: many repositories get the immutable form with numeric IDs. See the README."
  type        = list(string)

  validation {
    condition     = length(var.subjects) > 0
    error_message = "subjects must name at least one workflow subject, otherwise the service account can never be assumed."
  }

  validation {
    condition     = alltrue([for s in var.subjects : startswith(s, "repo:")])
    error_message = "Every subject must start with \"repo:\", as GitHub issues them."
  }

  validation {
    condition     = alltrue([for s in var.subjects : !strcontains(s, "*")])
    error_message = "Subjects are matched exactly, so \"*\" is a literal character here and would never match. List each subject."
  }
}

variable "existing_federation_id" {
  description = "Reuse a federation instead of creating one. A federation only states that Yandex Cloud trusts GitHub tokens for this owner, so one per owner is enough: further identities pass its ID here and differ only in subjects and roles. Null creates a federation."
  type        = string
  default     = null
}

variable "bucket_roles" {
  description = "Roles on individual buckets, keyed by bucket name. The right scope for a deploy identity. The binding is authoritative for each (bucket, role) pair: it replaces any other members of that pair."
  type        = map(list(string))
  default     = {}
}

variable "folder_roles" {
  description = "Roles on the whole folder. Keep it empty unless a role has no bucket-level equivalent: a runner executes code that can arrive in a pull request."
  type        = list(string)
  default     = []
}

variable "description" {
  description = "Description of the service account and the federation."
  type        = string
  default     = ""
}

variable "labels" {
  description = "Labels of the federation."
  type        = map(string)
  default     = {}
}
