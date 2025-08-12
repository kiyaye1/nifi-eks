# NiFi on EKS 

This repo always:
1. Provisions **EKS** (default VPC + public subnets) with Terraform.
2. Builds a **NiFi** Docker image and **pushes to Docker Hub**.
3. Deploys to Kubernetes via **Ansible**.
4. Prints the public **NiFi URL** when done.

## Jenkins usage

Create two credentials:
- `aws-creds` — *Username:* AWS Access Key ID, *Password:* AWS Secret Access Key
- `dockerhub-creds` — *Username:* Docker Hub user, *Password:* Docker Hub password 

Run the Pipeline with:
- `ACTION = all` (provision + build + push + deploy), or `ACTION = down` (destroy).

params:
- `AWS_REGION`, `CLUSTER_NAME`, `K8S_VERSION`, `NODE_INSTANCE_TYPE`, `NODE_DESIRED`
- `DOCKERHUB_USER`, `IMAGE_TAG`, `NIFI_VERSION`

NiFi will be reachable at: `http://<elb-dns>:8080/nifi`
