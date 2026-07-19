output "ecr_repository_name" {
  description = "ECR repository name"
  value       = aws_ecr_repository.task_api.name
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.task_api.repository_url
}

output "secret_container_names" {
  description = "Names of Secrets Manager secret containers"
  value = {
    for key, secret in aws_secretsmanager_secret.container : key => secret.name
  }
}

output "secret_container_arns" {
  description = "ARNs of Secrets Manager secret containers"
  value = {
    for key, secret in aws_secretsmanager_secret.container : key => secret.arn
  }
}
