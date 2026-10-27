variable "project" {
  type    = string
  default = "habesha"
}

variable "environment" {
  type        = string
  description = "dev | staging | prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_cidr" {
  type = string
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "cluster_version" {
  type    = string
  default = "1.31"
}

variable "cluster_public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  type = list(string)
}

variable "node_min_size" {
  type = number
}

variable "node_max_size" {
  type = number
}

variable "node_desired_size" {
  type = number
}

variable "node_disk_size" {
  type    = number
  default = 100
}

variable "resource_profile" {
  type    = string
  default = "small"
}

variable "enable_xray" {
  type    = bool
  default = true
}

variable "app_namespace" {
  type    = string
  default = "ethiopian-culture"
}

variable "jenkins_git_repo_url" {
  type = string
}

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
  type        = map(string)
  default     = {}
  description = "Optional pins: jenkins, jfrog_platform, trivy_operator, trivy_server"
}
