locals {
  vertex_endpoint_filter = var.vertex_ai.endpoint_filter != null ? " AND resource.labels.endpoint_id=~\"${var.vertex_ai.endpoint_filter}\"" : ""
  vertex_base_filter     = "resource.type=\"aiplatform.googleapis.com/Endpoint\"${local.vertex_endpoint_filter}"
  vertex_labels          = merge(local.common_labels, { service = "vertex-ai" }, var.vertex_ai.labels)
}

# ── Online Prediction Errors ──────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "vertex_prediction_errors_warning" {
  count        = var.vertex_ai.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[VertexAI][WARNING] Online Prediction Errors High"
  combiner     = "OR"
  user_labels  = merge(local.vertex_labels, local.severity_warning)

  conditions {
    display_name = "Online prediction errors > ${var.vertex_ai.error_count_warning}/min"
    condition_threshold {
      filter          = "${local.vertex_base_filter} AND metric.type=\"aiplatform.googleapis.com/prediction/online/error_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vertex_ai.error_count_warning
      duration        = "${var.vertex_ai.duration_warning_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.endpoint_id"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Vertex AI online prediction endpoint is returning errors at a rate > ${var.vertex_ai.error_count_warning}/min. Check model health and input data quality. ${var.alert_documentation_prefix}/runbooks/vertex-ai-errors"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "vertex_prediction_errors_critical" {
  count        = var.vertex_ai.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[VertexAI][CRITICAL] Online Prediction Errors Critical"
  combiner     = "OR"
  user_labels  = merge(local.vertex_labels, local.severity_critical)

  conditions {
    display_name = "Online prediction errors > ${var.vertex_ai.error_count_critical}/min"
    condition_threshold {
      filter          = "${local.vertex_base_filter} AND metric.type=\"aiplatform.googleapis.com/prediction/online/error_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vertex_ai.error_count_critical
      duration        = "${var.vertex_ai.duration_critical_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.endpoint_id"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Vertex AI online prediction is failing critically at > ${var.vertex_ai.error_count_critical} errors/min. Model endpoint may be unhealthy. ${var.alert_documentation_prefix}/runbooks/vertex-ai-errors"
    mime_type = "text/markdown"
  }
}

# ── Prediction Latency P99 ────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "vertex_prediction_latency_warning" {
  count        = var.vertex_ai.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[VertexAI][WARNING] Prediction Latency P99 High"
  combiner     = "OR"
  user_labels  = merge(local.vertex_labels, local.severity_warning)

  conditions {
    display_name = "Online prediction P99 latency > ${var.vertex_ai.latency_p99_warning_ms}ms"
    condition_threshold {
      filter          = "${local.vertex_base_filter} AND metric.type=\"aiplatform.googleapis.com/prediction/online/response_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vertex_ai.latency_p99_warning_ms
      duration        = "${var.vertex_ai.duration_warning_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.endpoint_id"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Vertex AI online prediction P99 latency has exceeded ${var.vertex_ai.latency_p99_warning_ms}ms. Check model complexity and instance count. ${var.alert_documentation_prefix}/runbooks/vertex-ai-latency"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "vertex_prediction_latency_critical" {
  count        = var.vertex_ai.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[VertexAI][CRITICAL] Prediction Latency P99 Critical"
  combiner     = "OR"
  user_labels  = merge(local.vertex_labels, local.severity_critical)

  conditions {
    display_name = "Online prediction P99 latency > ${var.vertex_ai.latency_p99_critical_ms}ms"
    condition_threshold {
      filter          = "${local.vertex_base_filter} AND metric.type=\"aiplatform.googleapis.com/prediction/online/response_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vertex_ai.latency_p99_critical_ms
      duration        = "${var.vertex_ai.duration_critical_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.endpoint_id"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Vertex AI online prediction latency is critically high at P99 > ${var.vertex_ai.latency_p99_critical_ms}ms. Scale the endpoint or optimize the model. ${var.alert_documentation_prefix}/runbooks/vertex-ai-latency"
    mime_type = "text/markdown"
  }
}

# ── Endpoint CPU Utilisation ──────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "vertex_endpoint_cpu_warning" {
  count        = var.vertex_ai.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[VertexAI][WARNING] Endpoint CPU Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.vertex_labels, local.severity_warning)

  conditions {
    display_name = "Endpoint CPU utilisation > ${var.vertex_ai.cpu_warning_threshold * 100}%"
    condition_threshold {
      filter          = "${local.vertex_base_filter} AND metric.type=\"aiplatform.googleapis.com/prediction/online/cpu_utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vertex_ai.cpu_warning_threshold
      duration        = "${var.vertex_ai.duration_warning_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Vertex AI endpoint CPU utilisation has exceeded ${var.vertex_ai.cpu_warning_threshold * 100}%. Consider adding more serving nodes or using a more efficient model. ${var.alert_documentation_prefix}/runbooks/vertex-ai-cpu"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "vertex_endpoint_cpu_critical" {
  count        = var.vertex_ai.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[VertexAI][CRITICAL] Endpoint CPU Utilisation Critical"
  combiner     = "OR"
  user_labels  = merge(local.vertex_labels, local.severity_critical)

  conditions {
    display_name = "Endpoint CPU utilisation > ${var.vertex_ai.cpu_critical_threshold * 100}%"
    condition_threshold {
      filter          = "${local.vertex_base_filter} AND metric.type=\"aiplatform.googleapis.com/prediction/online/cpu_utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vertex_ai.cpu_critical_threshold
      duration        = "${var.vertex_ai.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Vertex AI endpoint CPU is at ${var.vertex_ai.cpu_critical_threshold * 100}%. Latency and errors will increase. Scale out the endpoint immediately. ${var.alert_documentation_prefix}/runbooks/vertex-ai-cpu"
    mime_type = "text/markdown"
  }
}

# ── Pipeline Task Failures ────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "vertex_pipeline_failures_warning" {
  count        = var.vertex_ai.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[VertexAI][WARNING] Pipeline Task Failures Detected"
  combiner     = "OR"
  user_labels  = merge(local.vertex_labels, local.severity_warning)

  conditions {
    display_name = "Pipeline task failure count > ${var.vertex_ai.pipeline_fail_warning}"
    condition_threshold {
      filter          = "resource.type=\"aiplatform.googleapis.com/PipelineJob\" AND metric.type=\"aiplatform.googleapis.com/pipeline/task/failed_run_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vertex_ai.pipeline_fail_warning
      duration        = "${var.vertex_ai.duration_warning_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Vertex AI pipeline tasks are failing. ${var.vertex_ai.pipeline_fail_warning}+ task failures detected. Check pipeline logs for errors. ${var.alert_documentation_prefix}/runbooks/vertex-ai-pipeline"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "vertex_pipeline_failures_critical" {
  count        = var.vertex_ai.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[VertexAI][CRITICAL] Pipeline Task Failures Critical"
  combiner     = "OR"
  user_labels  = merge(local.vertex_labels, local.severity_critical)

  conditions {
    display_name = "Pipeline task failure count > ${var.vertex_ai.pipeline_fail_critical}"
    condition_threshold {
      filter          = "resource.type=\"aiplatform.googleapis.com/PipelineJob\" AND metric.type=\"aiplatform.googleapis.com/pipeline/task/failed_run_count\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.vertex_ai.pipeline_fail_critical
      duration        = "${var.vertex_ai.duration_critical_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Vertex AI pipeline is experiencing widespread task failures (${var.vertex_ai.pipeline_fail_critical}+). ML workflows are disrupted. ${var.alert_documentation_prefix}/runbooks/vertex-ai-pipeline"
    mime_type = "text/markdown"
  }
}
