variable "rds_enabled" {
  description = "Whether to create RDS resources for Week 8"
  type        = bool
  default     = true
}

variable "rds_db_name" {
  description = "Initial database name for task API"
  type        = string
  default     = "taskdb"
}

variable "rds_username" {
  description = "Master username for RDS PostgreSQL"
  type        = string
  default     = "taskuser"
}

variable "rds_password" {
  description = "Master password for RDS PostgreSQL"
  type        = string
  sensitive   = true
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version for RDS"
  type        = string
  default     = "17.10"
}

variable "rds_instance_class" {
  description = "RDS instance class for primary and read replica"
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GiB for RDS primary"
  type        = number
  default     = 20
}

variable "rds_backup_retention_period" {
  description = "Backup retention period. Required for read replica source DB."
  type        = number
  default     = 1
}
