locals {
  cluster_identifier = coalesce(var.cluster_identifier, "db-${random_uuid.resource.id}")
}

resource "random_uuid" "resource" {}

resource "aws_rds_cluster" "resource" {
  cluster_identifier = local.cluster_identifier
  engine             = var.engine
  engine_version     = var.engine_version
  engine_mode        = var.engine_mode

  database_name   = var.database_name
  master_username = var.master_username

  master_password               = var.master_password
  master_password_wo            = var.master_password_wo
  master_password_wo_version    = var.master_password_wo_version
  manage_master_user_password   = var.manage_master_user_password
  master_user_secret_kms_key_id = var.master_user_secret_kms_key_id

  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_id

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids
  availability_zones     = var.availability_zones
  port                   = var.port
  network_type           = var.network_type

  db_cluster_parameter_group_name  = var.db_cluster_parameter_group_name
  db_instance_parameter_group_name = var.db_instance_parameter_group_name

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  copy_tags_to_snapshot        = var.copy_tags_to_snapshot
  delete_automated_backups     = var.delete_automated_backups
  backtrack_window             = var.backtrack_window

  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.final_snapshot_identifier
  deletion_protection       = var.deletion_protection

  allow_major_version_upgrade = var.allow_major_version_upgrade
  apply_immediately           = var.apply_immediately

  enabled_cloudwatch_logs_exports     = var.enabled_cloudwatch_logs_exports
  iam_database_authentication_enabled = var.iam_database_authentication_enabled
  iam_roles                           = var.iam_roles
  enable_http_endpoint                = var.enable_http_endpoint

  snapshot_identifier           = var.snapshot_identifier
  global_cluster_identifier     = var.global_cluster_identifier
  replication_source_identifier = var.replication_source_identifier
  ca_certificate_identifier     = var.ca_certificate_identifier

  dynamic "serverlessv2_scaling_configuration" {
    for_each = var.serverlessv2_scaling_configuration[*]

    content {
      min_capacity             = serverlessv2_scaling_configuration.value.min_capacity
      max_capacity             = serverlessv2_scaling_configuration.value.max_capacity
      seconds_until_auto_pause = serverlessv2_scaling_configuration.value.seconds_until_auto_pause
    }
  }

  tags = var.tags

  # AWS sets this on a global secondary; applying the resulting diff promotes it out of the global cluster.
  lifecycle {
    ignore_changes = [replication_source_identifier]
  }
}

resource "aws_rds_cluster_instance" "resource" {
  count = var.instance_count

  identifier         = "${local.cluster_identifier}-${count.index}"
  cluster_identifier = aws_rds_cluster.resource.id
  engine             = aws_rds_cluster.resource.engine
  engine_version     = aws_rds_cluster.resource.engine_version
  instance_class     = var.instance_class

  db_subnet_group_name    = var.db_subnet_group_name
  db_parameter_group_name = var.db_instance_parameter_group_name
  publicly_accessible     = var.publicly_accessible
  promotion_tier          = var.promotion_tier

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_retention_period
  performance_insights_kms_key_id       = var.performance_insights_kms_key_id

  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = var.monitoring_role_arn

  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  apply_immediately          = var.apply_immediately
  ca_cert_identifier         = var.ca_certificate_identifier
  copy_tags_to_snapshot      = var.copy_tags_to_snapshot

  tags = var.tags
}

output "id" {
  description = "The ID of the cluster."
  value       = aws_rds_cluster.resource.id
}

output "arn" {
  description = "The ARN of the cluster."
  value       = aws_rds_cluster.resource.arn
}

output "cluster_identifier" {
  description = "The identifier of the cluster."
  value       = aws_rds_cluster.resource.cluster_identifier
}

output "endpoint" {
  description = "Writer endpoint of the cluster. Send every write here — it follows the current writer across a failover."
  value       = aws_rds_cluster.resource.endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint of the cluster, load-balancing connections across its read replicas. Empty until at least one replica exists."
  value       = aws_rds_cluster.resource.reader_endpoint
}

output "port" {
  description = "Port the cluster accepts connections on."
  value       = aws_rds_cluster.resource.port
}

output "hosted_zone_id" {
  description = "Route53 hosted zone ID of the cluster's endpoint, for an alias record in terraform-aws-route53-record."
  value       = aws_rds_cluster.resource.hosted_zone_id
}

output "cluster_resource_id" {
  description = "AWS's own immutable ID for the cluster, used in IAM database authentication policies."
  value       = aws_rds_cluster.resource.cluster_resource_id
}

output "master_user_secret" {
  description = "Secrets Manager secret AWS created for the master password, when manage_master_user_password is enabled. Empty otherwise."
  value       = aws_rds_cluster.resource.master_user_secret
}

output "instance_identifiers" {
  description = "Identifiers of every instance in the cluster, in creation order. The first is the initial writer."
  value       = aws_rds_cluster_instance.resource[*].identifier
}

output "instance_endpoints" {
  description = "Per-instance endpoints, for connecting to one specific instance rather than through the cluster's writer or reader endpoint."
  value       = aws_rds_cluster_instance.resource[*].endpoint
}
