locals {
  gcs_bucket_filter = var.cloud_storage.bucket_name_filter != null ? " AND resource.labels.bucket_name=~\"${var.cloud_storage.bucket_name_filter}\"" : ""
  gcs_base_filter   = "resource.type=\"gcs_bucket\"${local.gcs_bucket_filter}"
  gcs_labels        = merge(local.common_labels, { service = "cloud-storage" }, var.cloud_storage.labels)
}

# ── API Request Errors ────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "gcs_error_count_warning" {
  count        = var.cloud_storage.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[GCS][WARNING] API Request Errors High"
  combiner     = "OR"
  user_labels  = merge(local.gcs_labels, local.severity_warning)

  conditions {
    display_name = "GCS API errors > ${var.cloud_storage.error_count_warning}/min"
    condition_threshold {
      filter          = "${local.gcs_base_filter} AND metric.type=\"storage.googleapis.com/api/request_count\" AND metric.labels.response_code!=\"200\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_storage.error_count_warning
      duration        = "${var.cloud_storage.duration_warning_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.bucket_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "GCS bucket API errors have exceeded ${var.cloud_storage.error_count_warning}/min. Check for permission issues, quota limits, or application bugs. ${var.alert_documentation_prefix}/runbooks/gcs-errors"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "gcs_error_count_critical" {
  count        = var.cloud_storage.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[GCS][CRITICAL] API Request Errors Critical"
  combiner     = "OR"
  user_labels  = merge(local.gcs_labels, local.severity_critical)

  conditions {
    display_name = "GCS API errors > ${var.cloud_storage.error_count_critical}/min"
    condition_threshold {
      filter          = "${local.gcs_base_filter} AND metric.type=\"storage.googleapis.com/api/request_count\" AND metric.labels.response_code!=\"200\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_storage.error_count_critical
      duration        = "${var.cloud_storage.duration_critical_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.bucket_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "GCS bucket API errors are critically high at ${var.cloud_storage.error_count_critical}/min. Dependent workloads may be failing. ${var.alert_documentation_prefix}/runbooks/gcs-errors"
    mime_type = "text/markdown"
  }
}

# ── Total Storage Bytes (Cost Control) ───────────────────────────────────────

resource "google_monitoring_alert_policy" "gcs_total_bytes_warning" {
  count        = var.cloud_storage.enabled && var.cloud_storage.total_bytes_warning != null ? 1 : 0
  project      = var.project_id
  display_name = "[GCS][WARNING] Bucket Storage Size High"
  combiner     = "OR"
  user_labels  = merge(local.gcs_labels, local.severity_warning)

  conditions {
    display_name = "Bucket total bytes > ${var.cloud_storage.total_bytes_warning}"
    condition_threshold {
      filter          = "${local.gcs_base_filter} AND metric.type=\"storage.googleapis.com/storage/total_bytes\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_storage.total_bytes_warning
      duration        = "${var.cloud_storage.duration_warning_secs}s"
      aggregations {
        alignment_period   = "3600s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "GCS bucket storage size has exceeded the warning threshold. Review lifecycle policies and consider archiving old objects to Coldline/Archive storage. ${var.alert_documentation_prefix}/runbooks/gcs-storage-cost"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "gcs_total_bytes_critical" {
  count        = var.cloud_storage.enabled && var.cloud_storage.total_bytes_critical != null ? 1 : 0
  project      = var.project_id
  display_name = "[GCS][CRITICAL] Bucket Storage Size Critical"
  combiner     = "OR"
  user_labels  = merge(local.gcs_labels, local.severity_critical)

  conditions {
    display_name = "Bucket total bytes > ${var.cloud_storage.total_bytes_critical}"
    condition_threshold {
      filter          = "${local.gcs_base_filter} AND metric.type=\"storage.googleapis.com/storage/total_bytes\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_storage.total_bytes_critical
      duration        = "${var.cloud_storage.duration_critical_secs}s"
      aggregations {
        alignment_period   = "3600s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "GCS bucket storage size has exceeded the critical threshold. Costs are very high. Implement or enforce lifecycle deletion policies. ${var.alert_documentation_prefix}/runbooks/gcs-storage-cost"
    mime_type = "text/markdown"
  }
}

# ── Dual-Region Replication Lag ───────────────────────────────────────────────

resource "google_monitoring_alert_policy" "gcs_replication_lag_warning" {
  count        = var.cloud_storage.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[GCS][WARNING] Dual-Region Replication Lag High"
  combiner     = "OR"
  user_labels  = merge(local.gcs_labels, local.severity_warning)

  conditions {
    display_name = "Replication RPO lag > ${var.cloud_storage.replication_lag_warning_secs}s"
    condition_threshold {
      filter          = "${local.gcs_base_filter} AND metric.type=\"storage.googleapis.com/storage/object_replication/recovery_point_objective\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_storage.replication_lag_warning_secs
      duration        = "${var.cloud_storage.duration_warning_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "GCS dual-region replication RPO has exceeded ${var.cloud_storage.replication_lag_warning_secs}s. Disaster recovery guarantees may be weakened. ${var.alert_documentation_prefix}/runbooks/gcs-replication"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "gcs_replication_lag_critical" {
  count        = var.cloud_storage.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[GCS][CRITICAL] Dual-Region Replication Lag Critical"
  combiner     = "OR"
  user_labels  = merge(local.gcs_labels, local.severity_critical)

  conditions {
    display_name = "Replication RPO lag > ${var.cloud_storage.replication_lag_critical_secs}s"
    condition_threshold {
      filter          = "${local.gcs_base_filter} AND metric.type=\"storage.googleapis.com/storage/object_replication/recovery_point_objective\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_storage.replication_lag_critical_secs
      duration        = "${var.cloud_storage.duration_critical_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "GCS dual-region replication RPO has exceeded ${var.cloud_storage.replication_lag_critical_secs}s. DR objectives are breached. Investigate replication pipeline. ${var.alert_documentation_prefix}/runbooks/gcs-replication"
    mime_type = "text/markdown"
  }
}
