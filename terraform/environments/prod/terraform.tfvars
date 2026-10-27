environment = "prod"
region      = "us-east-1"

vpc_cidr           = "10.30.0.0/16"
single_nat_gateway = false # one NAT per AZ

node_instance_types = ["m5.2xlarge"]
node_min_size       = 3
node_max_size       = 6
node_desired_size   = 3
node_disk_size      = 200

resource_profile         = "large"
enable_xray              = true
artifactory_storage_size = "300Gi"
postgres_storage_size    = "100Gi"

jenkins_git_repo_url = "https://github.com/YOUR-ORG/ethiopian-culture-platform.git"
jenkins_git_branch   = "main"

# REQUIRED for prod: restrict to your corporate CIDRs.
cluster_public_access_cidrs = ["203.0.113.0/24"]
allowed_cidrs               = ["203.0.113.0/24"]

# Image pulls by the kubelet need HTTPS. Terminate TLS on the NLB with an ACM cert
# and point artifactory_registry_host at the DNS name you create for it.
# artifactory_registry_host  = "artifactory.prod.example.com"
# registry_insecure          = false
# artifactory_lb_annotations = {
#   "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"  = "arn:aws:acm:us-east-1:111122223333:certificate/xxxx"
#   "service.beta.kubernetes.io/aws-load-balancer-ssl-ports" = "443"
# }
