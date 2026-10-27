data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name = "${var.project}-${var.environment}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)
  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Theme       = "ethiopian-food-and-culture"
  }
}

# ---------------------------------------------------------------- network
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = local.name
  cidr = var.vpc_cidr
  azs  = local.azs

  private_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 48)]

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = !var.single_nat_gateway
  enable_dns_hostnames   = true

  public_subnet_tags  = { "kubernetes.io/role/elb" = 1 }
  private_subnet_tags = { "kubernetes.io/role/internal-elb" = 1 }
}

# ---------------------------------------------------------------- EKS
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = local.name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access           = true
  cluster_endpoint_public_access_cidrs     = var.cluster_public_access_cidrs
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true, before_compute = true }
  }

  eks_managed_node_groups = {
    platform = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size

      use_custom_launch_template = false
      disk_size                  = var.node_disk_size

      labels = { workload = "platform" }
    }
  }
}

# EBS CSI driver (needed for Jenkins / Artifactory / Postgres PVCs).
# Kept outside the eks module to avoid a module <-> IRSA dependency cycle.
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name             = "${local.name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = module.ebs_csi_irsa.iam_role_arn

  depends_on = [module.eks]
}

# ---------------------------------------------------------------- platform
# Jenkins, JFrog Artifactory + Xray, Trivy server + Trivy Operator
module "platform" {
  source = "../modules/platform"

  project       = var.project
  environment   = var.environment
  region        = var.region
  app_namespace = var.app_namespace

  enable_xray      = var.enable_xray
  resource_profile = var.resource_profile

  jenkins_git_repo_url = var.jenkins_git_repo_url
  jenkins_git_branch   = var.jenkins_git_branch
  allowed_cidrs        = var.allowed_cidrs

  artifactory_registry_host  = var.artifactory_registry_host
  registry_insecure          = var.registry_insecure
  artifactory_lb_annotations = var.artifactory_lb_annotations
  artifactory_license        = var.artifactory_license

  jenkins_storage_size     = var.jenkins_storage_size
  artifactory_storage_size = var.artifactory_storage_size
  postgres_storage_size    = var.postgres_storage_size
  chart_versions           = var.chart_versions

  depends_on = [module.eks, aws_eks_addon.ebs_csi]
}
