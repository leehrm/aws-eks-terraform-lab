# ------------------------------------------------------------
# RDS Subnet Group
# - RDS를 Private Subnet 2개에 배치하기 위한 subnet group
# ------------------------------------------------------------

resource "aws_db_subnet_group" "task_api" {
  count = var.rds_enabled ? 1 : 0

  name       = "${var.project_name}-rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-rds-subnet-group"
  }
}

# ------------------------------------------------------------
# RDS Security Group
# - EKS private subnet에서 PostgreSQL 5432 접근 허용
# ------------------------------------------------------------

resource "aws_security_group" "rds" {
  count = var.rds_enabled ? 1 : 0

  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow PostgreSQL from EKS private subnets"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"

    cidr_blocks = var.private_subnet_cidrs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# ------------------------------------------------------------
# RDS Primary PostgreSQL
# - Write 전용으로 사용할 Primary DB
# ------------------------------------------------------------

resource "aws_db_instance" "task_api_primary" {
  count = var.rds_enabled ? 1 : 0

  identifier = "${var.project_name}-postgres-primary"

  engine         = "postgres"
  engine_version = var.rds_engine_version
  instance_class = var.rds_instance_class

  allocated_storage = var.rds_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.rds_db_name
  username = var.rds_username
  password = var.rds_password

  port = 5432

  db_subnet_group_name   = aws_db_subnet_group.task_api[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]
  publicly_accessible    = false

  backup_retention_period = var.rds_backup_retention_period
  backup_window           = "18:00-19:00"
  maintenance_window      = "sun:19:00-sun:20:00"

  deletion_protection = false
  skip_final_snapshot = true

  auto_minor_version_upgrade = false
  copy_tags_to_snapshot      = true

  tags = {
    Name = "${var.project_name}-postgres-primary"
    Role = "primary"
  }
}

# ------------------------------------------------------------
# RDS PostgreSQL Read Replica
# - Read 전용으로 사용할 Replica DB
# ------------------------------------------------------------

resource "aws_db_instance" "task_api_replica" {
  count = var.rds_enabled ? 1 : 0

  identifier = "${var.project_name}-postgres-replica"

  replicate_source_db = aws_db_instance.task_api_primary[0].identifier

  instance_class = var.rds_instance_class

  storage_type      = "gp3"
  storage_encrypted = true

  publicly_accessible = false

  vpc_security_group_ids = [aws_security_group.rds[0].id]

  auto_minor_version_upgrade = false
  skip_final_snapshot        = true
  deletion_protection        = false
  copy_tags_to_snapshot      = true

  tags = {
    Name = "${var.project_name}-postgres-replica"
    Role = "replica"
  }

  depends_on = [
    aws_db_instance.task_api_primary
  ]
}
