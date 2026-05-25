output "aws_account_id" {
  description = "AWS account ID used by Terraform"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_caller_arn" {
  description = "AWS caller ARN used by Terraform"
  value       = data.aws_caller_identity.current.arn
}

output "availability_zones" {
  description = "Availability zones used"
  value       = local.azs
}

output "vpc_id" {
  description = "Created VPC ID"
  value       = aws_vpc.main.id
}

output "internet_gateway_id" {
  description = "Created Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "public_subnet_ids" {
  description = "Created public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Created private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_route_table_id" {
  description = "Created public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "Created private route table ID"
  value       = aws_route_table.private.id
}

output "nat_gateway_id" {
  description = "Created NAT Gateway ID"
  value       = aws_nat_gateway.main.id
}

output "nat_eip_public_ip" {
  description = "Public IP address of NAT Gateway Elastic IP"
  value       = aws_eip.nat.public_ip
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_version" {
  description = "EKS Kubernetes version"
  value       = aws_eks_cluster.main.version
}

output "eks_node_group_name" {
  description = "EKS managed node group name"
  value       = aws_eks_node_group.default.node_group_name
}

output "eks_node_role_arn" {
  description = "EKS node IAM role ARN"
  value       = aws_iam_role.eks_node.arn
}

output "ebs_csi_addon_name" {
  description = "EKS EBS CSI add-on name"
  value       = aws_eks_addon.ebs_csi.addon_name
}

output "ebs_csi_role_arn" {
  description = "IAM role ARN for EBS CSI driver"
  value       = aws_iam_role.ebs_csi.arn
}

output "gp3_storage_class_name" {
  description = "Default gp3 StorageClass name"
  value       = kubernetes_storage_class_v1.gp3.metadata[0].name
}

output "karpenter_controller_role_arn" {
  description = "IAM role ARN for Karpenter controller"
  value       = aws_iam_role.karpenter_controller.arn
}

output "karpenter_node_role_arn" {
  description = "IAM role ARN for Karpenter managed nodes"
  value       = aws_iam_role.karpenter_node.arn
}

output "karpenter_node_instance_profile_name" {
  description = "Instance profile name for Karpenter managed nodes"
  value       = aws_iam_instance_profile.karpenter_node.name
}

output "karpenter_interruption_queue_name" {
  description = "SQS queue name for Karpenter interruption handling"
  value       = aws_sqs_queue.karpenter_interruption.name
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}
