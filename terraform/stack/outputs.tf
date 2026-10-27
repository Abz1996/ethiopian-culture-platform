locals {
  kubectl_config_cmd = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"

  summary = {
    environment = var.environment
    project     = var.project
    region      = var.region
    cluster = {
      name               = module.eks.cluster_name
      endpoint           = module.eks.cluster_endpoint
      kubernetes_version = var.cluster_version
      kubeconfig_command = local.kubectl_config_cmd
    }
    jenkins = {
      url              = module.platform.jenkins_url
      admin_user       = "admin"
      password_command = "terraform -chdir=terraform/stack output -raw jenkins_admin_password"
      pipeline_job     = "ethiopian-culture-deploy"
    }
    artifactory = {
      url              = module.platform.artifactory_url
      docker_registry  = module.platform.docker_registry_host
      admin_user       = "admin"
      password_command = "terraform -chdir=terraform/stack output -raw artifactory_admin_password"
    }
    xray = {
      enabled = var.enable_xray
      url     = module.platform.xray_url
    }
    trivy = {
      server_url_in_cluster = module.platform.trivy_server_url
      operator_namespace    = "trivy-system"
      reports_command       = "kubectl get vulnerabilityreports -A"
    }
    app = {
      namespace    = var.app_namespace
      helm_release = "habesha"
      url_command  = "kubectl -n ${var.app_namespace} get svc habesha-culture -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
    }
    helm_chart_versions = module.platform.chart_versions
  }
}

output "environment_summary" {
  description = "Everything you need to know about this environment (no secrets)."
  value       = local.summary
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "configure_kubectl" {
  value = local.kubectl_config_cmd
}

output "jenkins_url" {
  value = module.platform.jenkins_url
}

output "artifactory_url" {
  value = module.platform.artifactory_url
}

output "xray_url" {
  value = module.platform.xray_url
}

output "trivy_server_url" {
  value = module.platform.trivy_server_url
}

output "jenkins_admin_password" {
  value     = module.platform.jenkins_admin_password
  sensitive = true
}

output "artifactory_admin_password" {
  value     = module.platform.artifactory_admin_password
  sensitive = true
}

# --- Written to terraform/environments/<env>/outputs/ after every apply ---
resource "local_file" "summary_json" {
  filename = "${path.root}/../environments/${var.environment}/outputs/summary.json"
  content  = jsonencode(local.summary)
}

resource "local_file" "summary_md" {
  filename = "${path.root}/../environments/${var.environment}/outputs/summary.md"
  content  = templatefile("${path.module}/summary.md.tftpl", { s = local.summary })
}
