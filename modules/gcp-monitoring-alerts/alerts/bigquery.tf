locals {
  bigquery_labels = merge(local.common_labels, { service = "bigquery" }, var.bigquery.labels)
}

# ── Slot Utilisation (MQL ratio) ─────────────────────────────────────────────

resource "google_monitoring_alert_policy" "bigquery_slot_warning" {
  count        = var.bigquery.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[BigQuery][WARNING] Slot Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.bigquery_labels, local.severity_warning)

  conditions {
    display_name = "Slot utilisation ratio > ${var.bigquery.slot_utilization_warning * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch bigquery_project
        | metric 'bigquery.googleapis.com/slots/allocated_for_project'
        | group_by [resource.labels.project_id], [allocated: mean(val())]
        | join (
            fetch bigquery_reservation
            | metric 'bigquery.googleapis.com/reservation/num_baseline_slots'
            | group_by [resource.labels.project_id], [capacity: mean(val())]
          )
        | value if(capacity > 0, allocated / capacity, 0)
        | condition val() > ${var.bigquery.slot_utilization_warning}
      EOT
      duration = "${var.bigquery.duration_warning_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "BigQuery slot utilisation has exceeded ${var.bigquery.slot_utilization_warning * 100}%. Jobs may queue and experience increased latency. Review slot reservations and consider purchasing additional capacity. ${var.alert_documentation_prefix}/runbooks/bigquery-slots"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "bigquery_slot_critical" {
  count        = var.bigquery.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[BigQuery][CRITICAL] Slot Utilisation Critical"
  combiner     = "OR"
  user_labels  = merge(local.bigquery_labels, local.severity_critical)

  conditions {
    display_name = "Slot utilisation ratio > ${var.bigquery.slot_utilization_critical * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch bigquery_project
        | metric 'bigquery.googleapis.com/slots/allocated_for_project'
        | group_by [resource.labels.project_id], [allocated: mean(val())]
        | join (
            fetch bigquery_reservation
            | metric 'bigquery.googleapis.com/reservation/num_baseline_slots'
            | group_by [resource.labels.project_id], [capacity: mean(val())]
          )
        | value if(capacity > 0, allocated / capacity, 0)
        | condition val() > ${var.bigquery.slot_utilization_critical}
      EOT
      duration = "${var.bigquery.duration_critical_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "BigQuery slot utilisation is critically high at ${var.bigquery.slot_utilization_critical * 100}%. Jobs are heavily queued. Immediate action required. ${var.alert_documentation_prefix}/runbooks/bigquery-slots"
    mime_type = "text/markdown"
  }
}

# ── Job Execution Time ────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "bigquery_job_duration_warning" {
  count        = var.bigquery.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[BigQuery][WARNING] Job Execution Time High"
  combiner     = "OR"
  user_labels  = merge(local.bigquery_labels, local.severity_warning)

  conditions {
    display_name = "Job execution time > ${var.bigquery.job_execution_warning_secs}s"
    condition_threshold {
      filter          = "resource.type=\"bigquery_project\" AND metric.type=\"bigquery.googleapis.com/job/execution_times\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.bigquery.job_execution_warning_secs * 1000
      duration        = "${var.bigquery.duration_warning_secs}s"
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.project_id"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "BigQuery P99 job execution time has exceeded ${var.bigquery.job_execution_warning_secs}s. Review slow queries in BigQuery Information Schema. ${var.alert_documentation_prefix}/runbooks/bigquery-performance"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "bigquery_job_duration_critical" {
  count        = var.bigquery.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[BigQuery][CRITICAL] Job Execution Time Critical"
  combiner     = "OR"
  user_labels  = merge(local.bigquery_labels, local.severity_critical)

  conditions {
    display_name = "Job execution time > ${var.bigquery.job_execution_critical_secs}s"
    condition_threshold {
      filter          = "resource.type=\"bigquery_project\" AND metric.type=\"bigquery.googleapis.com/job/execution_times\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.bigquery.job_execution_critical_secs * 1000
      duration        = "${var.bigquery.duration_critical_secs}s"
      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.project_id"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "BigQuery job execution time is critically high at > ${var.bigquery.job_execution_critical_secs}s. This may indicate resource contention or inefficient queries. ${var.alert_documentation_prefix}/runbooks/bigquery-performance"
    mime_type = "text/markdown"
  }
}

# ── Dataset Table Count ───────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "bigquery_table_count_warning" {
  count        = var.bigquery.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[BigQuery][WARNING] Dataset Table Count High"
  combiner     = "OR"
  user_labels  = merge(local.bigquery_labels, local.severity_warning)

  conditions {
    display_name = "Dataset table count > ${var.bigquery.table_count_warning} (limit: 10,000)"
    condition_threshold {
      filter          = "resource.type=\"bigquery_dataset\" AND metric.type=\"bigquery.googleapis.com/storage/table_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.bigquery.table_count_warning
      duration        = "${var.bigquery.duration_warning_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "BigQuery dataset table count has exceeded ${var.bigquery.table_count_warning}. GCP enforces a hard limit of 10,000 tables per dataset. Plan for dataset partitioning or archival. ${var.alert_documentation_prefix}/runbooks/bigquery-tables"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "bigquery_table_count_critical" {
  count        = var.bigquery.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[BigQuery][CRITICAL] Dataset Table Count Near Limit"
  combiner     = "OR"
  user_labels  = merge(local.bigquery_labels, local.severity_critical)

  conditions {
    display_name = "Dataset table count > ${var.bigquery.table_count_critical} (limit: 10,000)"
    condition_threshold {
      filter          = "resource.type=\"bigquery_dataset\" AND metric.type=\"bigquery.googleapis.com/storage/table_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.bigquery.table_count_critical
      duration        = "${var.bigquery.duration_critical_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "BigQuery dataset table count has exceeded ${var.bigquery.table_count_critical}. Near the 10,000 table hard limit. New table creation will fail. Immediate action required. ${var.alert_documentation_prefix}/runbooks/bigquery-tables"
    mime_type = "text/markdown"
  }
}

# ── Failed Jobs (Log-based Metric) ───────────────────────────────────────────

resource "google_logging_metric" "bigquery_failed_jobs" {
  count   = var.bigquery.enabled ? 1 : 0
  project = var.project_id
  name    = "bigquery_failed_jobs"

  filter = <<-EOT
    resource.type="bigquery_project"
    protoPayload.serviceName="bigquery.googleapis.com"
    protoPayload.status.code!=0
    severity=ERROR
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    labels {
      key         = "project_id"
      value_type  = "STRING"
      description = "GCP project ID"
    }
  }

  label_extractors = {
    "project_id" = "EXTRACT(resource.labels.project_id)"
  }
}

resource "google_monitoring_alert_policy" "bigquery_failed_jobs_warning" {
  count      = var.bigquery.enabled ? 1 : 0
  project    = var.project_id
  depends_on = [google_logging_metric.bigquery_failed_jobs]

  display_name = "[BigQuery][WARNING] Failed Jobs High"
  combiner     = "OR"
  user_labels  = merge(local.bigquery_labels, local.severity_warning)

  conditions {
    display_name = "Failed BigQuery jobs > ${var.bigquery.failed_jobs_warning} per hour"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.bigquery_failed_jobs[0].name}\" AND resource.type=\"bigquery_project\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.bigquery.failed_jobs_warning
      duration        = "${var.bigquery.duration_warning_secs}s"
      aggregations {
        alignment_period     = "3600s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.project_id"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "More than ${var.bigquery.failed_jobs_warning} BigQuery jobs have failed in the past hour. Check job error details in the BigQuery console. ${var.alert_documentation_prefix}/runbooks/bigquery-jobs"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "bigquery_failed_jobs_critical" {
  count      = var.bigquery.enabled ? 1 : 0
  project    = var.project_id
  depends_on = [google_logging_metric.bigquery_failed_jobs]

  display_name = "[BigQuery][CRITICAL] Failed Jobs Critical"
  combiner     = "OR"
  user_labels  = merge(local.bigquery_labels, local.severity_critical)

  conditions {
    display_name = "Failed BigQuery jobs > ${var.bigquery.failed_jobs_critical} per hour"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.bigquery_failed_jobs[0].name}\" AND resource.type=\"bigquery_project\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.bigquery.failed_jobs_critical
      duration        = "${var.bigquery.duration_critical_secs}s"
      aggregations {
        alignment_period     = "3600s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.project_id"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "More than ${var.bigquery.failed_jobs_critical} BigQuery jobs have failed in the past hour. Systematic job failures may indicate a pipeline outage. ${var.alert_documentation_prefix}/runbooks/bigquery-jobs"
    mime_type = "text/markdown"
  }
}
