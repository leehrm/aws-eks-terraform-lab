variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-northeast-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "harim"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "aws-eks-terraform-lab"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "aws-eks-terraform-lab-eks"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "node_group_name" {
  description = "EKS managed node group name"
  type        = string
  default     = "default-ng"
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "node_disk_size" {
  description = "Worker node disk size in GiB"
  type        = number
  default     = 20
}

variable "node_ami_type" {
  description = "AMI type for EKS managed node group"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "karpenter_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "1.12.1"
}

variable "karpenter_namespace" {
  description = "Namespace where Karpenter controller is installed"
  type        = string
  default     = "kube-system"
}
