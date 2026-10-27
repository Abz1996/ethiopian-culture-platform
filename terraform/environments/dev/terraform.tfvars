environment = "dev"
region      = "us-east-1"

vpc_cidr           = "10.10.0.0/16"
single_nat_gateway = true

node_instance_types = ["t3.xlarge"]
node_min_size       = 3
node_max_size       = 4
node_desired_size   = 3
node_disk_size      = 100

resource_profile = "small"
enable_xray      = true

jenkins_git_repo_url = "https://github.com/YOUR-ORG/ethiopian-culture-platform.git"
jenkins_git_branch   = "main"

# Lock these down to your office/VPN CIDR!
cluster_public_access_cidrs = ["0.0.0.0/0"]
allowed_cidrs               = ["0.0.0.0/0"]
