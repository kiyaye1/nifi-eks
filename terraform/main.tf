variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-2"
}

provider "aws" {
  region = var.aws_region
}

# Use default VPC + default public subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# IAM: EKS cluster role
resource "aws_iam_role" "eks_cluster_role" {
  name = "eksClusterRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "eks.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS cluster
resource "aws_eks_cluster" "eks" {
  name     = "eks-ubuntu-cluster"
  version  = "1.33"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = data.aws_subnets.default_public.ids
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# IAM: Node role
resource "aws_iam_role" "eks_node_role" {
  name = "eksNodeRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "registry_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Ubuntu 24.04 EKS AMI for 1.33
data "aws_ssm_parameter" "ubuntu_eks_ami" {
  name = "/aws/service/canonical/ubuntu/eks/24.04/1.33/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_launch_template" "ubuntu_lt" {
  name_prefix   = "ubuntu-eks-nodes-"
  image_id      = data.aws_ssm_parameter.ubuntu_eks_ami.value
  instance_type = "t3.medium"

  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euxo pipefail
    /etc/eks/bootstrap.sh ${aws_eks_cluster.eks.name}
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "ubuntu-eks-node" }
  }
}

resource "aws_eks_node_group" "mng" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "ubuntu-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = data.aws_subnets.default_public.ids

  scaling_config {
    desired_size = 1
    max_size     = 1
    min_size     = 1
  }

  launch_template {
    id      = aws_launch_template.ubuntu_lt.id
    version = "$Latest"
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.registry_policy
  ]
}

output "cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}
