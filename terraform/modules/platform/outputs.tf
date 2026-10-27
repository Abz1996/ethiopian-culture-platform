output "jenkins_url" {
  value = local.jenkins_lb != "" ? "http://${local.jenkins_lb}:8080" : "pending (LoadBalancer not ready - re-run terraform apply)"
}

output "artifactory_url" {
  value = local.artifactory_lb != "" ? "http://${local.artifactory_lb}/ui/" : "pending (LoadBalancer not ready - re-run terraform apply)"
}

output "xray_url" {
  value = var.enable_xray ? (local.artifactory_lb != "" ? "http://${local.artifactory_lb}/ui/ (Xray lives under the Security & Compliance tab)" : "pending") : "disabled"
}

output "docker_registry_host" {
  value = local.docker_registry_host
}

output "trivy_server_url" {
  value = local.trivy_server_url
}

output "chart_versions" {
  value = {
    jenkins        = helm_release.jenkins.metadata[0].version
    jfrog_platform = helm_release.jfrog_platform.metadata[0].version
    trivy_server   = helm_release.trivy_server.metadata[0].version
    trivy_operator = helm_release.trivy_operator.metadata[0].version
  }
}

output "jenkins_admin_password" {
  value     = random_password.jenkins_admin.result
  sensitive = true
}

output "artifactory_admin_password" {
  value     = random_password.artifactory_admin.result
  sensitive = true
}
