output "rds_primary_endpoint" {
  description = "RDS Primary endpoint"
  value       = var.rds_enabled ? aws_db_instance.task_api_primary[0].address : null
}

output "rds_primary_port" {
  description = "RDS Primary port"
  value       = var.rds_enabled ? aws_db_instance.task_api_primary[0].port : null
}

output "rds_replica_endpoint" {
  description = "RDS Read Replica endpoint"
  value       = var.rds_enabled ? aws_db_instance.task_api_replica[0].address : null
}

output "rds_replica_port" {
  description = "RDS Read Replica port"
  value       = var.rds_enabled ? aws_db_instance.task_api_replica[0].port : null
}

output "rds_db_name" {
  description = "RDS database name"
  value       = var.rds_db_name
}

output "rds_username" {
  description = "RDS master username"
  value       = var.rds_username
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = var.rds_enabled ? aws_security_group.rds[0].id : null
}
