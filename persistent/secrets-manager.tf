locals {
  secret_container_names = {
    task_api_database = "/${var.project_name}/${var.environment_name}/task-api/database"
    redis_auth        = "/${var.project_name}/${var.environment_name}/redis/auth"
    grafana           = "/${var.project_name}/${var.environment_name}/observability/grafana"
    slack             = "/${var.project_name}/${var.environment_name}/observability/slack"
  }
}

resource "aws_secretsmanager_secret" "container" {
  for_each = local.secret_container_names

  name                    = each.value
  recovery_window_in_days = 30

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = each.value
  }
}
