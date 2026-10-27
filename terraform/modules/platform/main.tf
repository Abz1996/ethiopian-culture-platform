terraform {
  required_providers {
    helm       = { source = "hashicorp/helm" }
    kubernetes = { source = "hashicorp/kubernetes" }
    random     = { source = "hashicorp/random" }
  }
}

locals {
  profiles = {
    small = {
      jenkins     = { cpu = "500m", mem = "2Gi" }
      artifactory = { cpu = "1", mem = "3Gi", xmx = "-Xmx2g" }
      xray        = { cpu = "500m", mem = "1Gi" }
    }
    standard = {
      jenkins     = { cpu = "1", mem = "3Gi" }
      artifactory = { cpu = "2", mem = "6Gi", xmx = "-Xmx4g" }
      xray        = { cpu = "1", mem = "2Gi" }
    }
    large = {
      jenkins     = { cpu = "2", mem = "6Gi" }
      artifactory = { cpu = "4", mem = "12Gi", xmx = "-Xmx8g" }
      xray        = { cpu = "2", mem = "4Gi" }
    }
  }
  p = local.profiles[var.resource_profile]

  namespaces = {
    jenkins = "jenkins"
    jfrog   = "jfrog"
    trivy   = "trivy-system"
    app     = var.app_namespace
  }

  has_license = nonsensitive(var.artifactory_license != "")

  # In-cluster URL of the Artifactory nginx front door (used by Jenkins agents for REST calls)
  artifactory_internal_url = "http://jfrog-platform-artifactory-nginx.jfrog.svc.cluster.local"
  trivy_server_url         = "http://trivy-server.trivy-system.svc.cluster.local:4954"

  common_labels = {
    "app.kubernetes.io/part-of" = var.project
    "habesha/environment"       = var.environment
  }
}

# ------------------------------------------------------------------ namespaces
resource "kubernetes_namespace_v1" "this" {
  for_each = local.namespaces
  metadata {
    name   = each.value
    labels = local.common_labels
  }
}

# ------------------------------------------------------------------ secrets
resource "random_password" "jenkins_admin" {
  length  = 24
  special = false
}

resource "random_password" "artifactory_admin" {
  length      = 24
  special     = false
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
}

resource "random_id" "jfrog_master_key" {
  byte_length = 32
}

resource "random_id" "jfrog_join_key" {
  byte_length = 32
}

resource "kubernetes_secret_v1" "platform_credentials" {
  metadata {
    name      = "platform-credentials"
    namespace = kubernetes_namespace_v1.this["jenkins"].metadata[0].name
  }
  data = {
    "artifactory-user"     = "admin"
    "artifactory-password" = random_password.artifactory_admin.result
  }
}

resource "kubernetes_secret_v1" "artifactory_license" {
  count = local.has_license ? 1 : 0
  metadata {
    name      = "artifactory-license"
    namespace = kubernetes_namespace_v1.this["jfrog"].metadata[0].name
  }
  data = {
    "artifactory.lic" = var.artifactory_license
  }
}

# ------------------------------------------------------------------ JFrog Artifactory + Xray
resource "helm_release" "jfrog_platform" {
  name       = "jfrog-platform"
  namespace  = kubernetes_namespace_v1.this["jfrog"].metadata[0].name
  repository = "https://charts.jfrog.io"
  chart      = "jfrog-platform"
  version    = lookup(var.chart_versions, "jfrog_platform", null)
  timeout    = 1800
  wait       = true

  values = [templatefile("${path.module}/templates/jfrog-values.yaml.tftpl", {
    artifactory_cpu  = local.p.artifactory.cpu
    artifactory_mem  = local.p.artifactory.mem
    artifactory_xmx  = local.p.artifactory.xmx
    xray_cpu         = local.p.xray.cpu
    xray_mem         = local.p.xray.mem
    enable_xray      = var.enable_xray
    has_license      = local.has_license
    storage_size     = var.artifactory_storage_size
    postgres_size    = var.postgres_storage_size
    allowed_cidrs    = var.allowed_cidrs
    lb_annotations   = merge({ "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb" }, var.artifactory_lb_annotations)
  })]

  set_sensitive {
    name  = "global.masterKey"
    value = random_id.jfrog_master_key.hex
  }
  set_sensitive {
    name  = "global.joinKey"
    value = random_id.jfrog_join_key.hex
  }
  set_sensitive {
    name  = "artifactory.artifactory.admin.password"
    value = random_password.artifactory_admin.result
  }

  depends_on = [kubernetes_secret_v1.artifactory_license]
}

data "kubernetes_service_v1" "artifactory_lb" {
  metadata {
    name      = "jfrog-platform-artifactory-nginx"
    namespace = local.namespaces.jfrog
  }
  depends_on = [helm_release.jfrog_platform]
}

locals {
  artifactory_lb       = try(data.kubernetes_service_v1.artifactory_lb.status[0].load_balancer[0].ingress[0].hostname, "")
  docker_registry_host = var.artifactory_registry_host != "" ? var.artifactory_registry_host : local.artifactory_lb
}

# ------------------------------------------------------------------ Trivy (server for Jenkins + operator for in-cluster scanning)
resource "helm_release" "trivy_server" {
  name       = "trivy-server"
  namespace  = kubernetes_namespace_v1.this["trivy"].metadata[0].name
  repository = "https://aquasecurity.github.io/helm-charts/"
  chart      = "trivy"
  version    = lookup(var.chart_versions, "trivy_server", null)
  timeout    = 600
  wait       = true

  values = [yamlencode({
    service     = { type = "ClusterIP" }
    persistence = { enabled = true, size = "10Gi" }
  })]
}

resource "helm_release" "trivy_operator" {
  name       = "trivy-operator"
  namespace  = kubernetes_namespace_v1.this["trivy"].metadata[0].name
  repository = "https://aquasecurity.github.io/helm-charts/"
  chart      = "trivy-operator"
  version    = lookup(var.chart_versions, "trivy_operator", null)
  timeout    = 600
  wait       = true

  values = [yamlencode({
    trivy           = { ignoreUnfixed = true }
    operator        = { scanJobsConcurrentLimit = 3 }
    serviceMonitor  = { enabled = false }
  })]
}

# ------------------------------------------------------------------ Jenkins
resource "helm_release" "jenkins" {
  name       = "jenkins"
  namespace  = kubernetes_namespace_v1.this["jenkins"].metadata[0].name
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = lookup(var.chart_versions, "jenkins", null)
  timeout    = 900
  wait       = true

  values = [templatefile("${path.module}/templates/jenkins-values.yaml.tftpl", {
    cpu           = local.p.jenkins.cpu
    mem           = local.p.jenkins.mem
    storage       = var.jenkins_storage_size
    allowed_cidrs = var.allowed_cidrs
    git_repo_url  = var.jenkins_git_repo_url
    git_branch    = var.jenkins_git_branch
    global_env = {
      ENVIRONMENT           = var.environment
      APP_NAMESPACE         = var.app_namespace
      ARTIFACTORY_URL       = local.artifactory_internal_url
      ARTIFACTORY_REGISTRY  = local.docker_registry_host
      REGISTRY_INSECURE     = tostring(var.registry_insecure)
      DOCKER_REPO           = "docker-local"
      TRIVY_SERVER_URL      = local.trivy_server_url
      ENABLE_XRAY           = tostring(var.enable_xray)
    }
  })]

  set_sensitive {
    name  = "controller.admin.password"
    value = random_password.jenkins_admin.result
  }

  # Needs the Artifactory LB hostname and the Trivy server endpoint to exist first
  depends_on = [helm_release.jfrog_platform, helm_release.trivy_server, kubernetes_secret_v1.platform_credentials]
}

data "kubernetes_service_v1" "jenkins_lb" {
  metadata {
    name      = "jenkins"
    namespace = local.namespaces.jenkins
  }
  depends_on = [helm_release.jenkins]
}

locals {
  jenkins_lb = try(data.kubernetes_service_v1.jenkins_lb.status[0].load_balancer[0].ingress[0].hostname, "")
}

# ------------------------------------------------------------------ app namespace wiring
# Lets Jenkins deploy the Ethiopian-culture app into its own namespace only.
resource "kubernetes_role_v1" "jenkins_deployer" {
  metadata {
    name      = "jenkins-deployer"
    namespace = local.namespaces.app
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "services", "configmaps", "secrets", "serviceaccounts", "persistentvolumeclaims", "events"]
    verbs      = ["*"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets", "statefulsets"]
    verbs      = ["*"]
  }
  rule {
    api_groups = ["autoscaling"]
    resources  = ["horizontalpodautoscalers"]
    verbs      = ["*"]
  }
  rule {
    api_groups = ["networking.k8s.io", "policy"]
    resources  = ["ingresses", "poddisruptionbudgets"]
    verbs      = ["*"]
  }
}

resource "kubernetes_role_binding_v1" "jenkins_deployer" {
  metadata {
    name      = "jenkins-deployer"
    namespace = local.namespaces.app
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.jenkins_deployer.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "jenkins"
    namespace = local.namespaces.jenkins
  }
  depends_on = [helm_release.jenkins]
}

# imagePullSecret so the app pods can pull from Artifactory
resource "kubernetes_secret_v1" "registry_pull" {
  metadata {
    name      = "artifactory-pull"
    namespace = local.namespaces.app
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (local.docker_registry_host) = {
          username = "admin"
          password = random_password.artifactory_admin.result
          auth     = base64encode("admin:${random_password.artifactory_admin.result}")
        }
      }
    })
  }
}
