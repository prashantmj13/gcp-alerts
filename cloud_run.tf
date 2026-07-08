locals {
  cloud_run_service_filter  = var.cloud_run.service_name != null ? " AND resource.labels.service_name=\"${var.cloud_run.service_name}\"" : ""
  cloud_run_location_filter = var.cloud_run.location != null ? " AND resource.labels.location=\"${var.cloud_run.location}\"" : ""
  cloud_run_base_filter     = "resource.type=\"cloud_run_revision\"${local.cloud_run_service_filter}${local.cloud_run_location_filter}"
  cloud_run_labels          = merge(local.common_labels, { service = "cloud-run" }, var.cloud_run.labels)

  # MQL service filter clause
  cloud_run_mql_service_filter = var.cloud_run.service_name != null ? "| filter resource.labels.service_name = '${var.cloud_run.service_name}'" : ""
}

# ── Request Latency P99 ───────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "cloud_run_latency_warning" {
  count        = var.cloud_run.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudRun][WARNING] Request Latency P99 High"
  combiner     = "OR"
  user_labels  = merge(local.cloud_run_labels, local.severity_warning)

  conditions {
    display_name = "P99 request latency > ${var.cloud_run.latency_p99_warning_ms}ms"
    condition_threshold {
      filter          = "${local.cloud_run_base_filter} AND metric.type=\"run.googleapis.com/request_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_run.latency_p99_warning_ms
      duration        = "${var.cloud_run.duration_warning_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.service_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud Run P99 request latency has exceeded ${var.cloud_run.latency_p99_warning_ms}ms. Check service logs for slow handlers and downstream dependency latency. ${var.alert_documentation_prefix}/runbooks/cloud-run-latency"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "cloud_run_latency_critical" {
  count        = var.cloud_run.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudRun][CRITICAL] Request Latency P99 Critical"
  combiner     = "OR"
  user_labels  = merge(local.cloud_run_labels, local.severity_critical)

  conditions {
    display_name = "P99 request latency > ${var.cloud_run.latency_p99_critical_ms}ms"
    condition_threshold {
      filter          = "${local.cloud_run_base_filter} AND metric.type=\"run.googleapis.com/request_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_run.latency_p99_critical_ms
      duration        = "${var.cloud_run.duration_critical_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.service_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud Run P99 request latency has exceeded ${var.cloud_run.latency_p99_critical_ms}ms. Service is severely degraded. ${var.alert_documentation_prefix}/runbooks/cloud-run-latency"
    mime_type = "text/markdown"
  }
}

# ── Error Rate (MQL ratio: 5xx / total) ──────────────────────────────────────

resource "google_monitoring_alert_policy" "cloud_run_error_rate_warning" {
  count        = var.cloud_run.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudRun][WARNING] 5xx Error Rate High"
  combiner     = "OR"
  user_labels  = merge(local.cloud_run_labels, local.severity_warning)

  conditions {
    display_name = "5xx error rate > ${var.cloud_run.error_rate_warning_threshold * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch cloud_run_revision
        ${local.cloud_run_mql_service_filter}
        | metric 'run.googleapis.com/request_count'
        | align rate(1m)
        | group_by [resource.labels.service_name],
            [val: sum(if(metric.labels.response_code_class = "5xx", val(), 0)) / sum(val())]
        | condition val() > ${var.cloud_run.error_rate_warning_threshold}
      EOT
      duration = "${var.cloud_run.duration_warning_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud Run 5xx error rate has exceeded ${var.cloud_run.error_rate_warning_threshold * 100}%. Check application logs for errors. ${var.alert_documentation_prefix}/runbooks/cloud-run-errors"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "cloud_run_error_rate_critical" {
  count        = var.cloud_run.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudRun][CRITICAL] 5xx Error Rate Critical"
  combiner     = "OR"
  user_labels  = merge(local.cloud_run_labels, local.severity_critical)

  conditions {
    display_name = "5xx error rate > ${var.cloud_run.error_rate_critical_threshold * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch cloud_run_revision
        ${local.cloud_run_mql_service_filter}
        | metric 'run.googleapis.com/request_count'
        | align rate(1m)
        | group_by [resource.labels.service_name],
            [val: sum(if(metric.labels.response_code_class = "5xx", val(), 0)) / sum(val())]
        | condition val() > ${var.cloud_run.error_rate_critical_threshold}
      EOT
      duration = "${var.cloud_run.duration_critical_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud Run 5xx error rate has exceeded ${var.cloud_run.error_rate_critical_threshold * 100}%. Service is severely degraded. ${var.alert_documentation_prefix}/runbooks/cloud-run-errors"
    mime_type = "text/markdown"
  }
}

# ── Container Memory Utilisation ─────────────────────────────────────────────

resource "google_monitoring_alert_policy" "cloud_run_memory_warning" {
  count        = var.cloud_run.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudRun][WARNING] Container Memory Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.cloud_run_labels, local.severity_warning)

  conditions {
    display_name = "Container memory utilisation > ${var.cloud_run.memory_warning_threshold * 100}%"
    condition_threshold {
      filter          = "${local.cloud_run_base_filter} AND metric.type=\"run.googleapis.com/container/memory/utilizations\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_run.memory_warning_threshold
      duration        = "${var.cloud_run.duration_warning_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.service_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud Run container memory is at ${var.cloud_run.memory_warning_threshold * 100}% utilisation. Risk of OOM kills if load increases. ${var.alert_documentation_prefix}/runbooks/cloud-run-memory"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "cloud_run_memory_critical" {
  count        = var.cloud_run.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudRun][CRITICAL] Container Memory Near Limit"
  combiner     = "OR"
  user_labels  = merge(local.cloud_run_labels, local.severity_critical)

  conditions {
    display_name = "Container memory utilisation > ${var.cloud_run.memory_critical_threshold * 100}%"
    condition_threshold {
      filter          = "${local.cloud_run_base_filter} AND metric.type=\"run.googleapis.com/container/memory/utilizations\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_run.memory_critical_threshold
      duration        = "${var.cloud_run.duration_critical_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.service_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud Run container memory is at ${var.cloud_run.memory_critical_threshold * 100}% utilisation. OOM kills imminent. Increase memory limit or reduce memory consumption. ${var.alert_documentation_prefix}/runbooks/cloud-run-memory"
    mime_type = "text/markdown"
  }
}
