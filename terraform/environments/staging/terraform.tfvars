environment = "staging"
region      = "us-east-1"

vpc_cidr           = "10.20.0.0/16"
single_nat_gateway = true

node_instance_types = ["m5.xlarge"]
node_min_size       = 3
node_max_size       = 5
node_desired_size   = 3
node_disk_size      = 150

resource_profile = "standard"
enable_xray      = true

jenkins_git_repo_url = "https://github.com/YOUR-ORG/ethiopian-culture-platform.git"
jenkins_git_branch   = "main"

cluster_public_access_cidrs = ["0.0.0.0/0"]
allowed_cidrs               = ["0.0.0.0/0"]
