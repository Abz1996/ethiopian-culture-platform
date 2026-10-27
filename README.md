# 🇪🇹 Habesha Kitchen — Ethiopian Food & Culture on EKS

Terraform builds an **Amazon EKS** cluster per environment (`dev`, `staging`, `prod`) and installs
**Jenkins**, **JFrog Artifactory + Xray**, and **Trivy** as pods. A **Jenkins pipeline** then builds,
scans and deploys a small web app about Ethiopian dishes, traditions and holidays.
After every `terraform apply`, an **environment summary** is written for each environment.

```
                       ┌──────────────────────────── EKS (per environment) ────────────────────────────┐
 git push ─► Jenkins ──┤ kaniko build ─► Artifactory (docker-local) ─► Trivy + Xray scan ─► helm deploy │
   (pod)               │                                                                    ▼          │
                       │ ns: jenkins     ns: jfrog (Artifactory, Xray, Postgres, RabbitMQ)  ns: ethiopian-culture
                       │ ns: trivy-system (Trivy server + Trivy Operator scanning running workloads)   │
                       └────────────────────────────────────────────────────────────────────────────────┘
```

## Layout
```
terraform/
  bootstrap/            one-time S3 state bucket
  stack/                root module: VPC + EKS + EBS CSI + platform module + summary outputs
  modules/platform/     Helm releases: Jenkins, jfrog-platform (Artifactory+Xray), Trivy server/operator
  environments/<env>/   terraform.tfvars + backend.hcl (separate state per env)
helm/habesha-culture/   app chart (+ values-dev/staging/prod, smoke test)
app/                    Flask app: /, /api/dishes, /api/culture, /api/holidays, /healthz (+ tests)
Jenkinsfile             deploy pipeline
Makefile                make apply ENV=dev
```

## Quick start
```bash
# prerequisites: terraform >= 1.10, aws cli (authenticated), kubectl, helm (optional)

make bootstrap BUCKET=my-unique-habesha-tfstate      # once
# put that bucket name into terraform/environments/*/backend.hcl
# put your git repo URL + your CIDR into terraform/environments/*/terraform.tfvars

make apply ENV=dev          # ~25-35 min; Xray/Artifactory are slow to start
make apply ENV=staging
make apply ENV=prod
make summary                # merges all environment summaries
```

## Per-environment output (after `terraform apply`)
Written to `terraform/environments/<env>/outputs/summary.md` and `summary.json`, and shown by
`make outputs ENV=<env>`: cluster name + kubeconfig command, Jenkins / Artifactory / Xray URLs,
Docker registry host, Trivy endpoints, app namespace, and the deployed Helm chart versions.
Passwords are **not** written to files; fetch them with:
```bash
terraform -chdir=terraform/stack output -raw jenkins_admin_password
terraform -chdir=terraform/stack output -raw artifactory_admin_password
```
(run `make init ENV=<env>` first so you are pointed at the right state).

## The Jenkins pipeline (`Jenkinsfile`)
Terraform creates the job `ethiopian-culture-deploy` (JCasC + Job DSL) and injects
`ENVIRONMENT`, `APP_NAMESPACE`, `ARTIFACTORY_*`, `TRIVY_SERVER_URL`, and credentials.

1. Unit tests (pytest)
2. Create `docker-local` repo in Artifactory
3. Build + push image with Kaniko (no Docker daemon needed)
4. **In parallel:** Trivy image scan (fails on HIGH/CRITICAL), Trivy IaC/Helm config scan, Xray build scan
5. Manual approval gate (prod only)
6. `helm upgrade --install --atomic` with `values-<env>.yaml`
7. `helm test` smoke test

## Things you must know before applying
- **Licenses:** Xray and the Docker repo type require an Artifactory Pro/Enterprise(+X) license.
  Pass it with `-var artifactory_license="$(cat artifactory.lic)"` or set `enable_xray = false`.
- **Registry TLS:** Kaniko and Trivy can push/scan over HTTP (`registry_insecure = true`), but the
  **kubelet cannot pull from a plain-HTTP registry**. For the deploy stage to succeed, put TLS in front
  of Artifactory (see the commented ACM example in `environments/prod/terraform.tfvars`), create a DNS
  record to the NLB hostname, set `artifactory_registry_host` and `registry_insecure = false`.
- **Chart values were written against the current upstream charts but not applied in this repo's
  authoring environment.** Run `terraform validate`, then on first apply check
  `helm show values jfrog/jfrog-platform` if a key is rejected. Pin versions via `chart_versions`
  (the summary file lists what was deployed).
- **Open by default:** `allowed_cidrs` and `cluster_public_access_cidrs` default to `0.0.0.0/0` in dev/staging. Restrict them.
- **Cost:** 3 nodes per environment plus NAT, NLBs and EBS volumes. Run `make destroy ENV=dev` when idle.
- Artifactory's admin account is used for the pull secret and pipeline; create a dedicated service user for real use.
