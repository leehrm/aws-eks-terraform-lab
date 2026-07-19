variable "aws_region" {
  description = "AWS region to deploy persistent resources"
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

variable "environment_name" {
  description = "Environment name used for persistent secret container naming"
  type        = string
  default     = "dev"
}

variable "ecr_repository_name" {
  description = "ECR repository name for application image"
  type        = string
  default     = "task-api"
}
