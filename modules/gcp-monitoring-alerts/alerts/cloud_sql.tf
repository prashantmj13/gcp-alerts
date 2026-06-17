locals {
  cloud_sql_db_filter = var.cloud_sql.database_id_filter != null ? " AND resource.labels.database_id=~\"${var.cloud_sql.database_id_filter}\"" : ""
  cloud_sql_base_filter = "resource.type=\"cloudsql_database\"${local.cloud_sql_db_filter}"
  cloud_sql_labels      = merge(local.common_labels, { service = "cloud-sql" }, var.cloud_sql.labels)
}

# ── CPU Utilisation ───────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "cloud_sql_cpu_warning" {
  count        = var.cloud_sql.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudSQL][WARNING] CPU Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.cloud_sql_labels, local.severity_warning)

  conditions {
    display_name = "Cloud SQL CPU utilisation > ${var.cloud_sql.cpu_warning_threshold * 100}%"
    condition_threshold {
      filter          = "${local.cloud_sql_base_filter} AND metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_sql.cpu_warning_threshold
      duration        = "${var.cloud_sql.duration_warning_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud SQL CPU utilisation has exceeded ${var.cloud_sql.cpu_warning_threshold * 100}%. Check for slow queries using Cloud SQL Insights. ${var.alert_documentation_prefix}/runbooks/cloud-sql-cpu"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "cloud_sql_cpu_critical" {
  count        = var.cloud_sql.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudSQL][CRITICAL] CPU Utilisation Critical"
  combiner     = "OR"
  user_labels  = merge(local.cloud_sql_labels, local.severity_critical)

  conditions {
    display_name = "Cloud SQL CPU utilisation > ${var.cloud_sql.cpu_critical_threshold * 100}%"
    condition_threshold {
      filter          = "${local.cloud_sql_base_filter} AND metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_sql.cpu_critical_threshold
      duration        = "${var.cloud_sql.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud SQL CPU utilisation has exceeded ${var.cloud_sql.cpu_critical_threshold * 100}%. Database performance is severely impacted. Consider upgrading the instance or killing long-running queries. ${var.alert_documentation_prefix}/runbooks/cloud-sql-cpu"
    mime_type = "text/markdown"
  }
}

# ── Memory Utilisation ────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "cloud_sql_memory_warning" {
  count        = var.cloud_sql.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudSQL][WARNING] Memory Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.cloud_sql_labels, local.severity_warning)

  conditions {
    display_name = "Cloud SQL memory utilisation > ${var.cloud_sql.memory_warning_threshold * 100}%"
    condition_threshold {
      filter          = "${local.cloud_sql_base_filter} AND metric.type=\"cloudsql.googleapis.com/database/memory/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_sql.memory_warning_threshold
      duration        = "${var.cloud_sql.duration_warning_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud SQL memory utilisation has exceeded ${var.cloud_sql.memory_warning_threshold * 100}%. Review buffer pool and connection counts. ${var.alert_documentation_prefix}/runbooks/cloud-sql-memory"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "cloud_sql_memory_critical" {
  count        = var.cloud_sql.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudSQL][CRITICAL] Memory Utilisation Critical"
  combiner     = "OR"
  user_labels  = merge(local.cloud_sql_labels, local.severity_critical)

  conditions {
    display_name = "Cloud SQL memory utilisation > ${var.cloud_sql.memory_critical_threshold * 100}%"
    condition_threshold {
      filter          = "${local.cloud_sql_base_filter} AND metric.type=\"cloudsql.googleapis.com/database/memory/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_sql.memory_critical_threshold
      duration        = "${var.cloud_sql.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud SQL memory utilisation has exceeded ${var.cloud_sql.memory_critical_threshold * 100}%. Out-of-memory risk is high. ${var.alert_documentation_prefix}/runbooks/cloud-sql-memory"
    mime_type = "text/markdown"
  }
}

# ── Disk Utilisation ──────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "cloud_sql_disk_warning" {
  count        = var.cloud_sql.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudSQL][WARNING] Disk Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.cloud_sql_labels, local.severity_warning)

  conditions {
    display_name = "Cloud SQL disk utilisation > ${var.cloud_sql.disk_warning_threshold * 100}%"
    condition_threshold {
      filter          = "${local.cloud_sql_base_filter} AND metric.type=\"cloudsql.googleapis.com/database/disk/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_sql.disk_warning_threshold
      duration        = "${var.cloud_sql.duration_warning_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud SQL disk is ${var.cloud_sql.disk_warning_threshold * 100}% full. Plan for disk expansion or data archival. ${var.alert_documentation_prefix}/runbooks/cloud-sql-disk"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "cloud_sql_disk_critical" {
  count        = var.cloud_sql.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudSQL][CRITICAL] Disk Utilisation Critical"
  combiner     = "OR"
  user_labels  = merge(local.cloud_sql_labels, local.severity_critical)

  conditions {
    display_name = "Cloud SQL disk utilisation > ${var.cloud_sql.disk_critical_threshold * 100}%"
    condition_threshold {
      filter          = "${local.cloud_sql_base_filter} AND metric.type=\"cloudsql.googleapis.com/database/disk/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_sql.disk_critical_threshold
      duration        = "${var.cloud_sql.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud SQL disk is ${var.cloud_sql.disk_critical_threshold * 100}% full. Expand disk immediately to prevent write failures. ${var.alert_documentation_prefix}/runbooks/cloud-sql-disk"
    mime_type = "text/markdown"
  }
}

# ── Active Connections ────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "cloud_sql_connections_warning" {
  count        = var.cloud_sql.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudSQL][WARNING] Connection Count High"
  combiner     = "OR"
  user_labels  = merge(local.cloud_sql_labels, local.severity_warning)

  conditions {
    display_name = "Connection count > ${var.cloud_sql.connections_warning_threshold * 100}% of max_connections"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch cloudsql_database
        | metric 'cloudsql.googleapis.com/database/network/connections'
        | group_by [resource.labels.database_id], [val: mean(val())]
        | condition val() > ${var.cloud_sql.connections_warning_threshold}
      EOT
      duration = "${var.cloud_sql.duration_warning_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud SQL connection count is high (above ${var.cloud_sql.connections_warning_threshold * 100}% threshold). Consider using Cloud SQL Auth Proxy with connection pooling. ${var.alert_documentation_prefix}/runbooks/cloud-sql-connections"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "cloud_sql_connections_critical" {
  count        = var.cloud_sql.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudSQL][CRITICAL] Connection Count Near Limit"
  combiner     = "OR"
  user_labels  = merge(local.cloud_sql_labels, local.severity_critical)

  conditions {
    display_name = "Connection count near max_connections"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch cloudsql_database
        | metric 'cloudsql.googleapis.com/database/network/connections'
        | group_by [resource.labels.database_id], [val: mean(val())]
        | condition val() > ${var.cloud_sql.connections_critical_threshold}
      EOT
      duration = "${var.cloud_sql.duration_critical_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud SQL connections are critically high (${var.cloud_sql.connections_critical_threshold * 100}% threshold). New connections may be rejected. Implement PgBouncer or reduce connection count. ${var.alert_documentation_prefix}/runbooks/cloud-sql-connections"
    mime_type = "text/markdown"
  }
}

# ── Replication Lag ───────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "cloud_sql_replication_lag_warning" {
  count        = var.cloud_sql.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudSQL][WARNING] Replication Lag High"
  combiner     = "OR"
  user_labels  = merge(local.cloud_sql_labels, local.severity_warning)

  conditions {
    display_name = "Read replica replication lag > ${var.cloud_sql.replication_lag_warning_secs}s"
    condition_threshold {
      filter          = "${local.cloud_sql_base_filter} AND metric.type=\"cloudsql.googleapis.com/database/replication/replica_lag\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_sql.replication_lag_warning_secs
      duration        = "${var.cloud_sql.duration_warning_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud SQL read replica lag exceeds ${var.cloud_sql.replication_lag_warning_secs}s. Read replicas may return stale data. ${var.alert_documentation_prefix}/runbooks/cloud-sql-replication"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "cloud_sql_replication_lag_critical" {
  count        = var.cloud_sql.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudSQL][CRITICAL] Replication Lag Critical"
  combiner     = "OR"
  user_labels  = merge(local.cloud_sql_labels, local.severity_critical)

  conditions {
    display_name = "Read replica replication lag > ${var.cloud_sql.replication_lag_critical_secs}s"
    condition_threshold {
      filter          = "${local.cloud_sql_base_filter} AND metric.type=\"cloudsql.googleapis.com/database/replication/replica_lag\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_sql.replication_lag_critical_secs
      duration        = "${var.cloud_sql.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud SQL read replica lag exceeds ${var.cloud_sql.replication_lag_critical_secs}s. Failover readiness is compromised. Investigate primary write load and replica capacity. ${var.alert_documentation_prefix}/runbooks/cloud-sql-replication"
    mime_type = "text/markdown"
  }
}
