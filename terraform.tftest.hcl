mock_provider "aws" {}

run "invalid_cluster_identifier_is_rejected" {
  command = plan

  variables {
    cluster_identifier  = "0Bad_Cluster"
    instance_class      = "db.r7g.large"
    skip_final_snapshot = true
  }

  expect_failures = [var.cluster_identifier]
}

run "final_snapshot_identifier_required_unless_skipped" {
  command = plan

  variables {
    instance_class = "db.r7g.large"
  }

  expect_failures = [var.final_snapshot_identifier]
}

run "master_password_and_managed_password_are_mutually_exclusive" {
  command = plan

  variables {
    instance_class              = "db.r7g.large"
    skip_final_snapshot         = true
    master_password             = "correct-horse-battery-staple"
    manage_master_user_password = true
  }

  expect_failures = [var.master_password_wo]
}

run "master_password_wo_requires_its_version" {
  command = plan

  variables {
    instance_class      = "db.r7g.large"
    skip_final_snapshot = true
    master_password_wo  = "correct-horse-battery-staple"
  }

  expect_failures = [var.master_password_wo_version]
}

run "monitoring_interval_requires_a_role" {
  command = plan

  variables {
    instance_class      = "db.r7g.large"
    skip_final_snapshot = true
    monitoring_interval = 60
  }

  expect_failures = [var.monitoring_role_arn]
}

run "cluster_identifier_defaults_to_prefixed_random_uuid" {
  command = apply

  variables {
    instance_class      = "db.r7g.large"
    skip_final_snapshot = true
  }

  assert {
    condition     = aws_rds_cluster.resource.cluster_identifier == "db-${random_uuid.resource.id}"
    error_message = "Leaving cluster_identifier unset should fall back to a letter-prefixed random_uuid, since AWS rejects an identifier that does not begin with a letter."
  }
}

run "one_instance_by_default" {
  command = plan

  variables {
    instance_class      = "db.r7g.large"
    skip_final_snapshot = true
  }

  assert {
    condition     = length(aws_rds_cluster_instance.resource) == 1
    error_message = "instance_count should default to a single writer instance."
  }
}

run "instance_count_creates_that_many_instances" {
  command = apply

  variables {
    cluster_identifier  = "my-cluster"
    instance_class      = "db.r7g.large"
    skip_final_snapshot = true
    instance_count      = 3
  }

  assert {
    condition     = length(aws_rds_cluster_instance.resource) == 3
    error_message = "Each instance_count should produce one cluster instance."
  }

  assert {
    condition     = aws_rds_cluster_instance.resource[0].identifier == "my-cluster-0"
    error_message = "Each instance should be named after the cluster, suffixed with its index."
  }

  assert {
    condition     = aws_rds_cluster_instance.resource[2].identifier == "my-cluster-2"
    error_message = "The last instance's index should match its position in the count."
  }
}

run "zero_instances_creates_a_cluster_with_none" {
  command = plan

  variables {
    instance_class      = "db.r7g.large"
    skip_final_snapshot = true
    instance_count      = 0
  }

  assert {
    condition     = length(aws_rds_cluster_instance.resource) == 0
    error_message = "instance_count of 0 should create the cluster with no instances, for a cluster whose capacity is attached separately."
  }
}

run "secure_defaults_are_applied" {
  command = plan

  variables {
    instance_class      = "db.r7g.large"
    skip_final_snapshot = true
  }

  assert {
    condition     = aws_rds_cluster.resource.storage_encrypted == true
    error_message = "Cluster storage encryption should be enabled by default."
  }

  assert {
    condition     = aws_rds_cluster.resource.backup_retention_period == 7
    error_message = "Automated backups should be retained for 7 days by default."
  }

  assert {
    condition     = aws_rds_cluster.resource.copy_tags_to_snapshot == true
    error_message = "Tags should be copied to snapshots by default."
  }

  assert {
    condition     = aws_rds_cluster_instance.resource[0].publicly_accessible == false
    error_message = "Cluster instances should not be publicly accessible by default."
  }

  assert {
    condition     = aws_rds_cluster.resource.engine == "aurora-postgresql"
    error_message = "The engine should default to Aurora PostgreSQL."
  }
}

run "no_serverless_scaling_block_by_default" {
  command = plan

  variables {
    instance_class      = "db.r7g.large"
    skip_final_snapshot = true
  }

  assert {
    condition     = length(aws_rds_cluster.resource.serverlessv2_scaling_configuration) == 0
    error_message = "Leaving serverlessv2_scaling_configuration unset should emit no scaling block."
  }
}

run "serverless_scaling_configuration_creates_one_block" {
  command = plan

  variables {
    instance_class      = "db.serverless"
    skip_final_snapshot = true
    serverlessv2_scaling_configuration = {
      min_capacity = 0.5
      max_capacity = 16
    }
  }

  assert {
    condition     = length(aws_rds_cluster.resource.serverlessv2_scaling_configuration) == 1
    error_message = "Setting serverlessv2_scaling_configuration should emit exactly one scaling block."
  }

  assert {
    condition     = aws_rds_cluster.resource.serverlessv2_scaling_configuration[0].max_capacity == 16
    error_message = "The scaling block's max_capacity should pass through unchanged."
  }
}

run "readme_default_example" {
  command = plan

  variables {
    engine                      = "aurora-postgresql"
    engine_version              = "16.4"
    instance_class              = "db.r7g.large"
    instance_count              = 2
    database_name               = "app"
    master_username             = "app"
    manage_master_user_password = true
    db_subnet_group_name        = "production-database"
    vpc_security_group_ids      = ["sg-1111"]
    final_snapshot_identifier   = "app-final"
  }
}

run "readme_serverless_example" {
  command = plan

  variables {
    instance_class  = "db.serverless"
    master_username = "app"
    serverlessv2_scaling_configuration = {
      min_capacity = 0
      max_capacity = 8
    }
    manage_master_user_password = true
    final_snapshot_identifier   = "app-final"
  }
}
