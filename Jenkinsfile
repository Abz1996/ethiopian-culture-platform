// Habesha Kitchen - build, scan, deploy pipeline.
// Runs on the Jenkins that Terraform installs into the EKS cluster and deploys
// to the SAME cluster. Environment-specific settings (ENVIRONMENT, APP_NAMESPACE,
// ARTIFACTORY_*, TRIVY_SERVER_URL, ...) are injected by Terraform via JCasC.

def podYaml = '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins
  containers:
    - name: python
      image: python:3.12-slim
      command: [cat]
      tty: true
    - name: kaniko
      image: gcr.io/kaniko-project/executor:debug
      command: [/busybox/cat]
      tty: true
    - name: trivy
      image: aquasec/trivy:latest
      command: [cat]
      tty: true
    - name: jfrog
      image: releases-docker.jfrog.io/jfrog/jfrog-cli-v2-jf:latest
      command: [cat]
      tty: true
    - name: helm
      image: alpine/k8s:1.31.2
      command: [cat]
      tty: true
'''

pipeline {
  agent { kubernetes { yaml podYaml } }

  options {
    timestamps()
    disableConcurrentBuilds()
    timeout(time: 45, unit: 'MINUTES')
  }

  environment {
    IMAGE_NAME  = 'habesha-culture'
    ARTIFACTORY = credentials('artifactory-creds')   // -> ARTIFACTORY_USR / ARTIFACTORY_PSW
  }

  stages {
    stage('Prepare') {
      steps {
        script {
          env.TAG   = "${env.BUILD_NUMBER}-${(env.GIT_COMMIT ?: 'local').take(7)}"
          env.IMAGE = "${env.ARTIFACTORY_REGISTRY}/${env.DOCKER_REPO}/${env.IMAGE_NAME}:${env.TAG}"
          echo "Environment: ${env.ENVIRONMENT} | Image: ${env.IMAGE}"
        }
      }
    }

    stage('Unit tests') {
      steps {
        container('python') {
          sh '''
            cd app
            pip install -q -r requirements.txt pytest
            python -m pytest -q
          '''
        }
      }
    }

    stage('Prepare Artifactory repo') {
      steps {
        container('jfrog') {
          // 200 = created, 400 = already exists; both fine
          sh '''
            code=$(curl -sS -o /dev/null -w '%{http_code}' -u "$ARTIFACTORY_USR:$ARTIFACTORY_PSW" \
              -X PUT -H 'Content-Type: application/json' \
              "$ARTIFACTORY_URL/artifactory/api/repositories/$DOCKER_REPO" \
              -d '{"rclass":"local","packageType":"docker","dockerApiVersion":"V2"}')
            echo "Create repo $DOCKER_REPO -> HTTP $code"
          '''
        }
      }
    }

    stage('Build & push image (Kaniko)') {
      steps {
        container('kaniko') {
          sh '''
            mkdir -p /kaniko/.docker
            AUTH=$(printf '%s:%s' "$ARTIFACTORY_USR" "$ARTIFACTORY_PSW" | base64 | tr -d '\\n')
            printf '{"auths":{"%s":{"auth":"%s"}}}' "$ARTIFACTORY_REGISTRY" "$AUTH" > /kaniko/.docker/config.json
            EXTRA=""
            if [ "$REGISTRY_INSECURE" = "true" ]; then EXTRA="--insecure --skip-tls-verify"; fi
            /kaniko/executor \
              --context "$WORKSPACE/app" \
              --dockerfile "$WORKSPACE/app/Dockerfile" \
              --destination "$IMAGE" \
              --image-name-tag-with-digest-file "$WORKSPACE/image-file" \
              $EXTRA
          '''
        }
      }
    }

    stage('Security scans') {
      parallel {
        stage('Trivy: image') {
          steps {
            container('trivy') {
              sh '''
                export TRIVY_USERNAME="$ARTIFACTORY_USR" TRIVY_PASSWORD="$ARTIFACTORY_PSW"
                if [ "$REGISTRY_INSECURE" = "true" ]; then export TRIVY_NON_SSL=true TRIVY_INSECURE=true; fi
                trivy image --server "$TRIVY_SERVER_URL" \
                  --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "$IMAGE"
              '''
            }
          }
        }
        stage('Trivy: IaC & Helm config') {
          steps {
            container('trivy') {
              // Report-only (exit-code 0): findings are visible but do not block
              sh 'trivy config --severity HIGH,CRITICAL --exit-code 0 terraform helm'
            }
          }
        }
        stage('JFrog Xray: build scan') {
          when { expression { env.ENABLE_XRAY == 'true' } }
          steps {
            container('jfrog') {
              sh '''
                jf config add habesha --url="$ARTIFACTORY_URL" --user="$ARTIFACTORY_USR" \
                  --password="$ARTIFACTORY_PSW" --insecure-tls=true --interactive=false --overwrite
                jf rt build-docker-create "$DOCKER_REPO" --image-file "$WORKSPACE/image-file" \
                  --build-name "$IMAGE_NAME" --build-number "$BUILD_NUMBER"
                jf rt build-publish "$IMAGE_NAME" "$BUILD_NUMBER"
                jf build-scan "$IMAGE_NAME" "$BUILD_NUMBER" --fail=true
              '''
            }
          }
        }
      }
    }

    stage('Approve production') {
      when { expression { env.ENVIRONMENT == 'prod' } }
      steps {
        timeout(time: 30, unit: 'MINUTES') {
          input message: 'Deploy this build to PRODUCTION?', ok: 'Deploy'
        }
      }
    }

    stage('Deploy (Helm)') {
      steps {
        container('helm') {
          sh '''
            helm upgrade --install habesha ./helm/habesha-culture \
              --namespace "$APP_NAMESPACE" \
              -f "helm/habesha-culture/values-$ENVIRONMENT.yaml" \
              --set image.repository="$ARTIFACTORY_REGISTRY/$DOCKER_REPO/$IMAGE_NAME" \
              --set image.tag="$TAG" \
              --atomic --wait --timeout 5m
          '''
        }
      }
    }

    stage('Smoke test') {
      steps {
        container('helm') {
          sh 'helm test habesha --namespace "$APP_NAMESPACE" --logs'
        }
      }
    }
  }

  post {
    success {
      container('helm') {
        sh '''
          echo "Deployed to $ENVIRONMENT. App endpoint:"
          kubectl -n "$APP_NAMESPACE" get svc habesha-culture \
            -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\\n"}'
        '''
      }
    }
    failure {
      echo 'Pipeline failed - check the Trivy / Xray stage output first.'
    }
  }
}
