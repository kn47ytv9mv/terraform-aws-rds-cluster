# terraform-aws-rds-cluster

Terraform module for an Aurora cluster — a set of compute instances
over shared, replicated storage, with an endpoint that follows the
writer across a failover.

## Cost

Aurora bills per instance-hour for each provisioned instance (or per
Aurora Capacity Unit-hour for Serverless v2), plus storage and I/O
consumed, backup storage beyond the free allotment equal to the cluster
size, and data transfer. Each added `instance_count` is a full
instance-hour charge. `backtrack_window` bills per change record
stored. See AWS's
[RDS pricing](https://aws.amazon.com/rds/aurora/pricing/) page for
current rates.

## Design

For a single non-Aurora database — PostgreSQL, MySQL, MariaDB, Oracle,
or SQL Server on its own attached volume — use
[`terraform-aws-db-instance`](https://github.com/kn47ytv9mv/terraform-aws-db-instance)
instead. Aurora is a genuinely different shape and the two do not share
a resource.

The cluster and its instances are bundled into one module because they
are never useful apart: a cluster with no instances serves no traffic,
the instances are homogeneous, and nothing outside references one
specific instance — connections go through the writer or reader
endpoint, not to a named member. This is the same bundling reasoning as
[`terraform-aws-efs`](https://github.com/kn47ytv9mv/terraform-aws-efs)
and its mount targets. Settings that AWS models per-instance
(`instance_class`, `promotion_tier`, `publicly_accessible`, monitoring)
are applied identically to every instance; a cluster whose members must
genuinely differ is past what this module covers.

`instance_count` defaults to 1, which is a single writer and no
failover target. Raise it to at least 2 for a cluster that must survive
losing its writer without downtime — Aurora promotes the lowest
`promotion_tier` healthy reader automatically. Setting it to 0 creates
the cluster with no instances, valid for a cluster whose capacity is
attached separately.

### Serverless v2

Serverless v2 is not a separate `engine_mode`. Set `instance_class` to
`'db.serverless'` and supply `serverlessv2_scaling_configuration` — the
cluster stays `'provisioned'`. A `min_capacity` of 0 lets the cluster
scale to zero when idle, with `seconds_until_auto_pause` controlling how
long it waits first.

### Passwords

Three mutually exclusive options, in descending order of preference:
`manage_master_user_password` (AWS generates, stores, and rotates it in
Secrets Manager — no password passes through Terraform),
`master_password_wo` with `master_password_wo_version` (write-only,
never persisted to state), and `master_password` (stored in state in
plain text). See the `master_user_secret` output for the secret AWS
creates under the first option.

### Deliberately not covered

Multi-AZ DB clusters — the non-Aurora cluster type using
`db_cluster_instance_class`, `allocated_storage`, and `storage_type` —
are not exposed. They share this resource but are a different product
with a different cost model and different constraints, and folding both
into one module would make every variable conditional on which kind of
cluster is being built. Point-in-time restore, S3 import, and Active
Directory domain joining are likewise out of scope.

### Global databases, and the difference this module ignores

A cluster becomes a member of an Aurora global database through
`global_cluster_identifier`, pointing at a global cluster built with
[`terraform-aws-rds-global-cluster`](https://github.com/kn47ytv9mv/terraform-aws-rds-global-cluster).
The primary member carries `master_username` and `master_password`; a
secondary member sets neither, because the primary owns them. Set
`engine_version` only on the global cluster, not on its members, so a
global upgrade does not show as drift on every member.

**This module ignores changes to `replication_source_identifier` after
creation, and that is deliberate.** AWS populates the attribute itself on
a global secondary, so Terraform sees a difference it did not cause — and
the AWS provider responds to that attribute being cleared by calling
`PromoteReadReplicaDBCluster`, which removes the secondary from its
global database. Applying an ordinary-looking plan could therefore break
a global database in a way nothing in the plan output announces. The
`lifecycle` guard prevents it. The cost is that a deliberate change to
the value does nothing; replace the cluster instead.

## Usage

```hcl
module "cluster" {
  source = "kn47ytv9mv/rds-cluster/aws"

  engine         = "aurora-postgresql"
  engine_version = "16.4"
  instance_class = "db.r7g.large"
  instance_count = 2

  database_name   = "app"
  master_username = "app"

  manage_master_user_password = true

  db_subnet_group_name   = module.subnet_group.name
  vpc_security_group_ids = [module.security_group.id]

  final_snapshot_identifier = "app-final"
}
```

Or directly from this repository, as Serverless v2 scaling to zero when
idle:

```hcl
module "cluster" {
  source = "github.com/kn47ytv9mv/terraform-aws-rds-cluster"

  instance_class  = "db.serverless"
  master_username = "app"

  serverlessv2_scaling_configuration = {
    min_capacity = 0
    max_capacity = 8
  }

  manage_master_user_password = true
  final_snapshot_identifier   = "app-final"
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.11 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| cluster_identifier | Identifier of the cluster. Must begin with a letter and contain only lowercase alphanumeric characters and hyphens. If null, a unique identifier is generated. Each cluster instance is named after it, suffixed with its index. | `null` | no |
| engine | Cluster engine (`'aurora-postgresql'` or `'aurora-mysql'`). Cannot be changed after creation. | `"aurora-postgresql"` | no |
| engine_version | Engine version (e.g. `'16.4'`). If null, AWS picks its own current default. | `null` | no |
| engine_mode | Cluster mode. Leave null: every current cluster is `'provisioned'`, including Serverless v2 and including a member of a global database. `'global'` belongs to the retired Aurora MySQL 5.6 pattern. | `null` | no |
| instance_count | Number of instances in the cluster. The first is the writer; every other is a read replica. Raise to at least 2 to survive losing the writer without downtime. | `1` | no |
| instance_class | Compute and memory capacity of each cluster instance (e.g. `'db.r7g.large'`). Set `'db.serverless'` for Aurora Serverless v2. | `null` | no |
| serverlessv2_scaling_configuration | Aurora Serverless v2 capacity range in Aurora Capacity Units. Required when `instance_class` is `'db.serverless'`. `min_capacity` may be 0 or between 0.5 and 256; `max_capacity` between 1 and 256. | `null` | no |
| database_name | Name of a database to create inside the cluster when first provisioned. | `null` | no |
| master_username | Master username. Cannot be changed after creation without replacing the cluster. | `null` | no |
| master_password | Master password, stored in Terraform state in plain text. Prefer `manage_master_user_password` or `master_password_wo`. | `null` | no |
| master_password_wo | Master password as a write-only value, never persisted to state. Requires `master_password_wo_version`. | `null` | no |
| master_password_wo_version | Version counter for `master_password_wo`. Increment it to push a changed password. | `null` | no |
| manage_master_user_password | Whether AWS generates the master password and manages it in Secrets Manager, including rotation. The recommended option. | `null` | no |
| master_user_secret_kms_key_id | KMS key encrypting the Secrets Manager secret created by `manage_master_user_password`. | `null` | no |
| storage_encrypted | Whether cluster storage is encrypted at rest. Defaults true — encryption cannot be enabled in place afterward. | `true` | no |
| kms_key_id | ARN of the KMS key encrypting cluster storage, from `terraform-aws-kms-key`. | `null` | no |
| db_subnet_group_name | Name of the subnet group placing this cluster in a VPC, from `terraform-aws-db-subnet-group`. | `null` | no |
| vpc_security_group_ids | IDs of the security groups controlling network access, from `terraform-aws-vpc-security-groups`. | `null` | no |
| availability_zones | Availability zones the cluster may place instances in. AWS expands this to three regardless. | `null` | no |
| port | Port the cluster accepts connections on. If null, the engine's own default applies. | `null` | no |
| network_type | Network protocol the cluster accepts (`'IPV4'` or `'DUAL'`). | `null` | no |
| publicly_accessible | Whether each cluster instance gets a public IP and publicly resolvable DNS name. Defaults false. | `false` | no |
| db_cluster_parameter_group_name | Name of the parameter group applying cluster-wide engine configuration. | `null` | no |
| db_instance_parameter_group_name | Name of the parameter group applied to each instance, separate from the cluster-wide group. | `null` | no |
| backup_retention_period | Days of automated backups retained, 1 to 35. Defaults to 7. | `7` | no |
| preferred_backup_window | Daily UTC window automated backups are taken in (e.g. `'03:00-04:00'`). Must not overlap `preferred_maintenance_window`. | `null` | no |
| preferred_maintenance_window | Weekly UTC window AWS applies maintenance in (e.g. `'sun:05:00-sun:06:00'`). | `null` | no |
| copy_tags_to_snapshot | Whether the cluster's tags are copied onto its snapshots. | `true` | no |
| delete_automated_backups | Whether automated backups are deleted along with the cluster. | `null` | no |
| backtrack_window | Seconds of backtrack window, letting the cluster be rewound in place. Aurora MySQL only, billed per change record stored. | `null` | no |
| skip_final_snapshot | Whether destroying the cluster skips taking a final snapshot. Defaults false, which makes `final_snapshot_identifier` required. | `false` | no |
| final_snapshot_identifier | Name of the snapshot taken when the cluster is destroyed. Required unless `skip_final_snapshot` is true. | `null` | no |
| deletion_protection | Whether AWS refuses to delete the cluster while set. Enabling it makes `terraform destroy` fail until a separate apply turns it off. | `false` | no |
| auto_minor_version_upgrade | Whether AWS applies minor engine upgrades automatically during the maintenance window. | `null` | no |
| allow_major_version_upgrade | Whether a change to `engine_version` crossing a major version is permitted. | `null` | no |
| apply_immediately | Whether modifications are applied immediately rather than deferred to the next maintenance window. | `null` | no |
| performance_insights_enabled | Whether Performance Insights collects database load metrics on each instance. | `null` | no |
| performance_insights_retention_period | Days Performance Insights data is retained. 7 and 731 are always valid; other values must be a multiple of 31. | `null` | no |
| performance_insights_kms_key_id | ARN of the KMS key encrypting Performance Insights data. | `null` | no |
| monitoring_interval | Seconds between Enhanced Monitoring collections on each instance. Any non-zero value requires `monitoring_role_arn`. | `null` | no |
| monitoring_role_arn | ARN of an IAM role permitting RDS to publish Enhanced Monitoring metrics, from `terraform-aws-iam-role`. | `null` | no |
| enabled_cloudwatch_logs_exports | Log types exported to CloudWatch Logs. Valid types are engine-specific. | `null` | no |
| iam_database_authentication_enabled | Whether database accounts may authenticate with IAM credentials. | `null` | no |
| iam_roles | ARNs of IAM roles the cluster may assume, for features reaching other AWS services. | `null` | no |
| enable_http_endpoint | Whether the RDS Data API is enabled, allowing SQL over HTTPS without a persistent connection. | `null` | no |
| snapshot_identifier | Identifier or ARN of a snapshot to restore this cluster from. | `null` | no |
| global_cluster_identifier | Identifier of an Aurora global cluster to join this cluster to, from `terraform-aws-rds-global-cluster`. | `null` | no |
| replication_source_identifier | ARN of a source cluster or instance to make this cluster a cross-region read replica of. Changes are ignored after creation — see Design. | `null` | no |
| ca_certificate_identifier | Certificate authority bundle for the cluster's TLS certificate (e.g. `'rds-ca-rsa2048-g1'`). | `null` | no |
| promotion_tier | Failover priority of each instance, 0 to 15. Applied identically to every instance this module creates. | `null` | no |
| tags | A map of tags to assign to the cluster and every instance in it. | `null` | no |

## Outputs

| Name | Description |
|---|---|
| id | The ID of the cluster. |
| arn | The ARN of the cluster. |
| cluster_identifier | The identifier of the cluster. |
| endpoint | Writer endpoint of the cluster. Send every write here — it follows the current writer across a failover. |
| reader_endpoint | Reader endpoint, load-balancing across read replicas. Empty until at least one replica exists. |
| port | Port the cluster accepts connections on. |
| hosted_zone_id | Route53 hosted zone ID of the cluster's endpoint, for an alias record in `terraform-aws-route53-record`. |
| cluster_resource_id | AWS's own immutable ID for the cluster, used in IAM database authentication policies. |
| master_user_secret | Secrets Manager secret AWS created for the master password, when `manage_master_user_password` is enabled. Empty otherwise. |
| instance_identifiers | Identifiers of every instance in the cluster, in creation order. |
| instance_endpoints | Per-instance endpoints, for connecting to one specific instance. |

## License

MIT — see [LICENSE.md](LICENSE.md).
