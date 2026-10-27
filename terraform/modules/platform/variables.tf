variable "project" { type = string }
variable "environment" { type = string }
variable "region" { type = string }
variable "app_namespace" { type = string }

variable "enable_xray" {
  type    = bool
  default = true
}

variable "resource_profile" {
  type    = string
  default = "small"
  validation {
    condition     = contains(["small", "standard", "large"], var.resource_profile)
    error_message = "resource_profile must be small, standard or large."
  }
}

variable "jenkins_git_repo_url" { type = string }

variable "jenkins_git_branch" {
  type    = string
  default = "main"
}

variable "allowed_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "artifactory_registry_host" {
  type    = string
  default = ""
}

variable "registry_insecure" {
  type    = bool
  default = true
}

variable "artifactory_lb_annotations" {
  type    = map(string)
  default = {}
}

variable "artifactory_license" {
  type      = string
  default   = ""
  sensitive = true
}

variable "jenkins_storage_size" {
  type    = string
  default = "20Gi"
}

variable "artifactory_storage_size" {
  type    = string
  default = "100Gi"
}

variable "postgres_storage_size" {
  type    = string
  default = "50Gi"
}

variable "chart_versions" {
  type    = map(string)
  default = {}
}
