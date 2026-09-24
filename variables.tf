variable "cluster_identifier" {
  default     = null
  description = "Identifier of the cluster. Must begin with a letter and contain only lowercase alphanumeric characters and hyphens — AWS rejects anything else. If null, a unique identifier is generated. Each cluster instance is named after it, suffixed with its index."

  validation {
    condition     = var.cluster_identifier == null || can(regex("^[a-z][a-z0-9-]*$", var.cluster_identifier))
    error_message = "A cluster identifier must begin with a letter and contain only lowercase alphanumeric characters and hyphens."
  }
}

variable "engine" {
  default     = "aurora-postgresql"
  description = "Cluster engine ('aurora-postgresql' or 'aurora-mysql'). Defaults to Aurora PostgreSQL. Cannot be changed after creation."
}

variable "engine_version" {
  default     = null
  description = "Engine version (e.g. '16.4'). If null, AWS picks its own current default for the engine."
}

variable "engine_mode" {
  default     = null
  description = "Cluster mode. Leave this null: every current cluster is 'provisioned', including Serverless v2 (which is 'provisioned' with serverlessv2_scaling_configuration set) and including a member of an Aurora global database. The 'global' mode belongs to the retired Aurora MySQL 5.6 global pattern and is not how a global database is built today — join one with global_cluster_identifier instead."
}

variable "instance_count" {
  default     = 1
  description = "Number of instances in the cluster. The first is the writer; every other is a read replica that can be promoted on failover. Defaults to 1 — raise it to at least 2 for a cluster that must survive losing its writer without downtime."
}

variable "instance_class" {
  default     = null
  description = "Compute and memory capacity of each cluster instance (e.g. 'db.r7g.large'). Set 'db.serverless' to use Aurora Serverless v2, which also requires serverlessv2_scaling_configuration."
}

variable "serverlessv2_scaling_configuration" {
  default     = null
  description = "Aurora Serverless v2 capacity range, in Aurora Capacity Units. Required when instance_class is 'db.serverless'. min_capacity may be 0 (the cluster scales to zero when idle) or between 0.5 and 256; max_capacity is between 1 and 256. seconds_until_auto_pause only applies when min_capacity is 0."
  type = object({
    min_capacity             = number
    max_capacity             = number
    seconds_until_auto_pause = optional(number)
  })
}

variable "database_name" {
  default     = null
  description = "Name of a database to create inside the cluster when it is first provisioned. If null, no database is created."
}

variable "master_username" {
  default     = null
  description = "Master username. Cannot be changed after creation without replacing the cluster."
}

variable "master_password" {
  default     = null
  description = "Master password, stored in Terraform state in plain text. Prefer manage_master_user_password (AWS generates and rotates the password in Secrets Manager) or master_password_wo (never written to state at all). Mutually exclusive with both."
  sensitive   = true
}

variable "master_password_wo" {
  default     = null
  description = "Master password as a write-only value — sent to AWS during apply but never persisted to Terraform state. Requires master_password_wo_version. Mutually exclusive with master_password and manage_master_user_password."
  sensitive   = true

  validation {
    condition     = length([for v in [var.master_password, var.master_password_wo, var.manage_master_user_password == true ? true : null] : v if v != null]) <= 1
    error_message = "At most one of master_password, master_password_wo, or manage_master_user_password may be set."
  }
}

variable "master_password_wo_version" {
  default     = null
  description = "Version counter for master_password_wo. Increment it to push a changed password; leaving it unchanged leaves the password alone, since Terraform cannot see the write-only value itself to diff it."

  validation {
    condition     = (var.master_password_wo == null) == (var.master_password_wo_version == null)
    error_message = "master_password_wo and master_password_wo_version must be set together."
  }
}

variable "manage_master_user_password" {
  default     = null
  description = "Whether AWS generates the master password and manages it in Secrets Manager, including rotation. The recommended option — no password ever passes through Terraform. Mutually exclusive with master_password and master_password_wo. If null, AWS's own default (disabled) applies."
}

variable "master_user_secret_kms_key_id" {
  default     = null
  description = "KMS key encrypting the Secrets Manager secret created by manage_master_user_password. If null, AWS's own managed key is used."
}

variable "storage_encrypted" {
  default     = true
  description = "Whether cluster storage is encrypted at rest. Defaults true — encryption cannot be enabled in place afterward, only by restoring a snapshot into a new cluster."
}

variable "kms_key_id" {
  default     = null
  description = "ARN of the KMS key encrypting cluster storage, from terraform-aws-kms-key. Only used when storage_encrypted is true. If null, AWS's own managed key for RDS is used."
}

variable "db_subnet_group_name" {
  default     = null
  description = "Name of the subnet group placing this cluster in a VPC, from terraform-aws-db-subnet-group. If null, the cluster lands in the default VPC, which is rarely the intent."
}

variable "vpc_security_group_ids" {
  default     = null
  description = "IDs of the security groups controlling network access to the cluster, from terraform-aws-vpc-security-groups."
}

variable "availability_zones" {
  default     = null
  description = "Availability zones the cluster may place instances in. AWS expands this to three zones regardless, so supplying fewer does not constrain it. If null, AWS chooses."
}

variable "port" {
  default     = null
  description = "Port the cluster accepts connections on. If null, the engine's own default applies (5432 for Aurora PostgreSQL, 3306 for Aurora MySQL)."
}

variable "network_type" {
  default     = null
  description = "Network protocol the cluster accepts ('IPV4' or 'DUAL' for dual-stack IPv4 and IPv6). If null, AWS's own default applies."
}

variable "publicly_accessible" {
  default     = false
  description = "Whether each cluster instance gets a public IP address and a publicly resolvable DNS name. Defaults false — a database reachable from the internet is almost never the intent."
}

variable "db_cluster_parameter_group_name" {
  default     = null
  description = "Name of the parameter group applying cluster-wide engine configuration. Its family must match this cluster's engine and major version. If null, AWS's default applies."
}

variable "db_instance_parameter_group_name" {
  default     = null
  description = "Name of the parameter group applied to each instance in the cluster, separate from the cluster-wide group. If null, AWS's default applies."
}

variable "backup_retention_period" {
  default     = 7
  description = "Days of automated backups retained, 1 to 35. Defaults to 7 rather than AWS's own default, matching this family's direction elsewhere of enabling durability protections out of the box."
}

variable "preferred_backup_window" {
  default     = null
  description = "Daily UTC window automated backups are taken in (e.g. '03:00-04:00'). Must not overlap preferred_maintenance_window. If null, AWS assigns one."
}

variable "preferred_maintenance_window" {
  default     = null
  description = "Weekly UTC window AWS applies maintenance in (e.g. 'sun:05:00-sun:06:00'). If null, AWS assigns one."
}

variable "copy_tags_to_snapshot" {
  default     = true
  description = "Whether the cluster's tags are copied onto its snapshots. Defaults true, so a snapshot stays attributable to whatever created it long after the cluster is gone."
}

variable "delete_automated_backups" {
  default     = null
  description = "Whether automated backups are deleted along with the cluster. If null, AWS's own default (delete them) applies."
}

variable "backtrack_window" {
  default     = null
  description = "Seconds of backtrack window, letting the cluster be rewound in place to an earlier point without restoring a snapshot. Aurora MySQL only, and billed per change record stored. If null, backtracking is disabled."
}

variable "skip_final_snapshot" {
  default     = false
  description = "Whether destroying the cluster skips taking a final snapshot. Defaults false, so data is not lost to a single destroy — which means final_snapshot_identifier must be set."
}

variable "final_snapshot_identifier" {
  default     = null
  description = "Name of the snapshot taken when the cluster is destroyed. Required unless skip_final_snapshot is true. Must be unique among existing snapshots."

  validation {
    condition     = var.skip_final_snapshot || var.final_snapshot_identifier != null
    error_message = "final_snapshot_identifier is required unless skip_final_snapshot is true, since a destroy would otherwise fail at teardown time rather than here."
  }
}

variable "deletion_protection" {
  default     = false
  description = "Whether AWS refuses to delete the cluster while set. Defaults false, since enabling it makes terraform destroy fail until a separate apply turns it off again."
}

variable "auto_minor_version_upgrade" {
  default     = null
  description = "Whether AWS applies minor engine version upgrades automatically during the maintenance window. If null, AWS's own default (enabled) applies."
}

variable "allow_major_version_upgrade" {
  default     = null
  description = "Whether a change to engine_version crossing a major version is permitted. Without it, AWS rejects the upgrade rather than performing it."
}

variable "apply_immediately" {
  default     = null
  description = "Whether modifications are applied immediately rather than deferred to the next maintenance window. Immediate application can cause downtime. If null, AWS's own default (defer) applies."
}

variable "performance_insights_enabled" {
  default     = null
  description = "Whether Performance Insights collects database load metrics on each instance. If null, AWS's own default (disabled) applies."
}

variable "performance_insights_retention_period" {
  default     = null
  description = "Days Performance Insights data is retained. 7 (the free tier) and 731 are always valid; other values must be a multiple of 31."
}

variable "performance_insights_kms_key_id" {
  default     = null
  description = "ARN of the KMS key encrypting Performance Insights data. If null, AWS's own managed key is used."
}

variable "monitoring_interval" {
  default     = null
  description = "Seconds between Enhanced Monitoring metric collections on each instance (0 to disable, or 1, 5, 10, 15, 30, 60). Any non-zero value requires monitoring_role_arn."
}

variable "monitoring_role_arn" {
  default     = null
  description = "ARN of an IAM role permitting RDS to publish Enhanced Monitoring metrics to CloudWatch Logs, from terraform-aws-iam-role. Required whenever monitoring_interval is non-zero."

  validation {
    condition     = var.monitoring_interval == null || var.monitoring_interval == 0 || var.monitoring_role_arn != null
    error_message = "monitoring_role_arn is required whenever monitoring_interval is non-zero."
  }
}

variable "enabled_cloudwatch_logs_exports" {
  default     = null
  description = "Log types exported to CloudWatch Logs. Valid types are engine-specific ('postgresql' for Aurora PostgreSQL; 'audit', 'error', 'general', and 'slowquery' for Aurora MySQL). If null, no logs are exported."
}

variable "iam_database_authentication_enabled" {
  default     = null
  description = "Whether database accounts may authenticate with IAM credentials instead of a password. If null, AWS's own default (disabled) applies."
}

variable "iam_roles" {
  default     = null
  description = "ARNs of IAM roles the cluster may assume, for features that reach other AWS services (importing from S3, invoking Lambda). Each role must already trust the RDS service."
}

variable "enable_http_endpoint" {
  default     = null
  description = "Whether the RDS Data API is enabled, allowing SQL over HTTPS without a persistent connection. If null, AWS's own default (disabled) applies."
}

variable "snapshot_identifier" {
  default     = null
  description = "Identifier or ARN of a snapshot to restore this cluster from, instead of creating an empty one."
}

variable "global_cluster_identifier" {
  default     = null
  description = "Identifier of an Aurora global cluster to join this cluster to, making it a member of a cross-region global database. Create the global cluster with terraform-aws-rds-global-cluster and pass its id. A secondary member sets neither master_username nor master_password: the primary owns them."
}

variable "replication_source_identifier" {
  default     = null
  description = "ARN of a source cluster or instance to make this cluster a cross-region read replica of. Changes to this value are ignored after creation, because AWS populates it on a global database secondary and applying the resulting difference promotes that secondary out of its global cluster. To change it deliberately, replace the cluster."
}

variable "ca_certificate_identifier" {
  default     = null
  description = "Certificate authority bundle used for the cluster's TLS certificate (e.g. 'rds-ca-rsa2048-g1'). If null, AWS's own current default applies."
}

variable "promotion_tier" {
  default     = null
  description = "Failover priority of each instance, 0 to 15. Aurora promotes the lowest-numbered healthy reader when the writer fails. Applied identically to every instance this module creates — set it per-instance by reaching for the raw resource if they must differ."
}

variable "tags" {
  default     = null
  description = "A map of tags to assign to the cluster and every instance in it."
}
