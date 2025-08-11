# NiFi on EKS — One Jenkinsfile Repo

This repo lets you:
- Create an **EKS** cluster (Kubernetes **1.33**) in your default VPC.
- Build & push a **Docker** image of **Apache NiFi**.
- Deploy NiFi to the cluster with a `LoadBalancer` Service.

## Structure
```
.
├─ Jenkinsfile
├─ terraform/
│  ├─ versions.tf
│  └─ main.tf
├─ k8s/
│  ├─ namespace.yaml
│  ├─ deployment.yaml
│  └─ service.yaml
└─ docker/
   ├─ Dockerfile
   └─ .dockerignore
```

## Jenkins prerequisites
Install on the Jenkins agent: **Terraform**, **AWS CLI v2**, **kubectl**, **Maven**, **Docker**.

Create credentials:
- `aws-creds` — AWS access key/secret with EKS/EC2/IAM permissions.
- `dockerhub-creds` — Docker Hub username/password.

## Pipeline parameters
- `ACTION` — `eks_all` (infra+image+deploy), `eks_up`, `eks_deploy`, `image_only`, `eks_down`
- `NIFI_VERSION` — default `1.26.0`
- `DOCKERHUB_USER` — your Docker Hub username
- `IMAGE_TAG` — tag to push/deploy
- `AWS_REGION` — default `us-east-2`

## Run
- **First time**: Run with `ACTION=eks_all`. On success you’ll see a URL like `http://<elb-host-or-ip>:8080/nifi`.
- **Later**: Use `eks_deploy` to redeploy new images, `image_only` to just build/push, or `eks_down` to destroy infra.
