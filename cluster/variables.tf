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

variable "external_secrets_namespace" {
  description = "Namespace where External Secrets Operator is installed"
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_service_account_name" {
  description = "ServiceAccount name used by External Secrets Operator"
  type        = string
  default     = "external-secrets"
}

variable "secret_container_arns" {
  description = "Secrets Manager secret container ARNs External Secrets Operator may read"
  type        = map(string)
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
  default     = ["t3.large"]
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

variable "argocd_namespace" {
  description = "Namespace where ArgoCD is installed"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "9.5.17"
}

variable "argocd_apps_chart_version" {
  description = "argocd-apps Helm chart version for bootstrapping root applications"
  type        = string
  default     = "2.0.5"
}

variable "argocd_root_app_repo_url" {
  description = "GitOps repository URL watched by the ArgoCD root application"
  type        = string
  default     = "https://github.com/leehrm/gitops-argocd.git"
}

variable "argocd_root_app_target_revision" {
  description = "Git branch watched by the ArgoCD root application"
  type        = string
  default     = "deploy/dev"
}

variable "argocd_root_app_path" {
  description = "Path in the GitOps repository containing ArgoCD Application manifests"
  type        = string
  default     = "clusters/dev/applications"
}

variable "metrics_server_chart_version" {
  description = "Metrics Server Helm chart version"
  type        = string
  default     = "3.13.0"
}
