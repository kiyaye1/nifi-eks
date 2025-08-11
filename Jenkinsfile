pipeline {
  agent any

  parameters {
    choice(name: 'ACTION',
           choices: ['eks_all', 'eks_up', 'eks_deploy', 'image_only', 'eks_down'],
           description: 'What should this pipeline do?')
    string(name: 'NIFI_VERSION', defaultValue: '1.26.0', description: 'NiFi version')
    string(name: 'DOCKERHUB_USER', defaultValue: 'kiyaye1', description: 'Docker Hub username')
    string(name: 'IMAGE_TAG', defaultValue: '1.26.0', description: 'Docker image tag to push/deploy')
    string(name: 'AWS_REGION', defaultValue: 'us-east-2', description: 'AWS region')
  }

  environment {
    IMAGE_NAME    = "${params.DOCKERHUB_USER}/nifi-custom"
    FULL_TAG      = "${IMAGE_NAME}:${params.IMAGE_TAG}"
    K8S_NAMESPACE = "nifi"
    K8S_APP_NAME  = "nifi"
  }

  options { ansiColor('xterm') }

  stages {
    stage('Plan') {
      steps {
        echo "ACTION=${params.ACTION}"
        echo "Image => ${env.FULL_TAG}"
      }
    }

    /* ===================== EKS INFRA ===================== */
    stage('Terraform: EKS up') {
      when { anyOf { expression { params.ACTION == 'eks_all' }; expression { params.ACTION == 'eks_up' } } }
      steps {
        dir('terraform') {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
            sh '''
              set -e
              terraform -version
              terraform init -input=false
              terraform apply -auto-approve -var=aws_region=$AWS_REGION
            '''
          }
        }
      }
    }

    stage('kubectl configure') {
      when {
        anyOf {
          expression { params.ACTION == 'eks_all' }
          expression { params.ACTION == 'eks_up' }
          expression { params.ACTION == 'eks_deploy' }
        }
      }
      steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
          sh '''
            set -e
            CLUSTER_NAME=$(terraform -chdir=terraform output -raw cluster_name)
            aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
            kubectl version --short || true
          '''
        }
      }
    }

    /* ===================== IMAGE BUILD ===================== */
    stage('Checkout NiFi source') {
      when { anyOf { expression { params.ACTION == 'eks_all' }; expression { params.ACTION == 'image_only' } } }
      steps {
        sh '''
          set -e
          rm -rf nifi
          git clone https://github.com/apache/nifi.git
          cd nifi
          git checkout rel/nifi-$NIFI_VERSION
        '''
      }
    }

    stage('Build NiFi ZIP') {
      when { anyOf { expression { params.ACTION == 'eks_all' }; expression { params.ACTION == 'image_only' } } }
      steps {
        dir('nifi/nifi-assembly') {
          sh '''
            set -e
            mvn -v
            mvn clean install -Passembly -DskipTests -U
          '''
        }
      }
    }

    stage('Prepare Docker context') {
      when { anyOf { expression { params.ACTION == 'eks_all' }; expression { params.ACTION == 'image_only' } } }
      steps {
        script {
          def zipFile = "nifi/nifi-assembly/target/nifi-${params.NIFI_VERSION}-bin.zip"
          if (!fileExists(zipFile)) error "NiFi ZIP not found at ${zipFile}"
          sh '''
            set -e
            mkdir -p docker
          '''
          sh "cp ${zipFile} docker/"
        }
      }
    }

    stage('Build & Push Docker image') {
      when { anyOf { expression { params.ACTION == 'eks_all' }; expression { params.ACTION == 'image_only' } } }
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          dir('docker') {
            sh '''
              set -e
              docker version >/dev/null 2>&1 || { echo "Docker daemon unreachable"; exit 1; }
              echo "$DH_PASS" | docker login --username "$DH_USER" --password-stdin
              docker build --build-arg NIFI_ZIP=nifi-$NIFI_VERSION-bin.zip -t $FULL_TAG .
              docker push $FULL_TAG
            '''
          }
        }
      }
    }

    /* ===================== K8S DEPLOY ===================== */
    stage('Deploy to EKS') {
      when { anyOf { expression { params.ACTION == 'eks_all' }; expression { params.ACTION == 'eks_deploy' } } }
      steps {
        sh '''
          set -e
          # Ensure namespace
          kubectl apply -f k8s/namespace.yaml

          # Render Deployment with the built image
          sed "s|__IMAGE__|$FULL_TAG|g" k8s/deployment.yaml | kubectl apply -f -

          # Service (LoadBalancer)
          kubectl apply -f k8s/service.yaml

          echo "Waiting for EXTERNAL-IP..."
          for i in {1..60}; do
            OUT=$(kubectl -n nifi get svc nifi -o jsonpath='{.status.loadBalancer.ingress[0].hostname]' 2>/dev/null || true)
            if [ -z "$OUT" ]; then
              OUT=$(kubectl -n nifi get svc nifi -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
            fi
            if [ -n "$OUT" ]; then
              echo "NiFi URL: http://$OUT:8080/nifi"
              exit 0
            fi
            sleep 10
          done
          echo "LoadBalancer not ready yet. Check later with: kubectl -n nifi get svc nifi"
        '''
      }
    }

    stage('Terraform: EKS down') {
      when { expression { params.ACTION == 'eks_down' } }
      steps {
        dir('terraform') {
          withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
            sh '''
              set -e
              terraform init -input=false
              terraform destroy -auto-approve -var=aws_region=$AWS_REGION
            '''
          }
        }
      }
    }
  }

  post {
    success { echo "Done. ACTION=${params.ACTION}, image=${env.FULL_TAG}" }
    failure { echo "Pipeline failed." }
  }
}
