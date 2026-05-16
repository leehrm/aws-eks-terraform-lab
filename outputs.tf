output "aws_account_id" {
  description = "AWS account ID used by Terraform"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_caller_arn" {
  description = "AWS caller ARN used by Terraform"
  value       = data.aws_caller_identity.current.arn
}

output "available_azs" {
  description = "Available availability zones in the selected region"
  value       = data.aws_availability_zones.available.names
}
