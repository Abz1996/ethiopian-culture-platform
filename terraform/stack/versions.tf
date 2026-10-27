terraform {
  required_version = ">= 1.10.0"

  # Partial config: supplied by environments/<env>/backend.hcl
  backend "s3" {}

  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 5.70" }
    helm       = { source = "hashicorp/helm", version = "~> 2.15" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.33" }
    random     = { source = "hashicorp/random", version = "~> 3.6" }
    local      = { source = "hashicorp/local", version = "~> 2.5" }
  }
}
