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
