locals {
  apigee_proxy_filter = var.apigee.proxy_name_filter != null ? " AND resource.labels.proxy_name=~\"${var.apigee.proxy_name_filter}\"" : ""
  apigee_base_filter  = "resource.type=\"apigee.googleapis.com/ProxyV2\"${local.apigee_proxy_filter}"
  apigee_labels       = merge(local.common_labels, { service = "apigee" }, var.apigee.labels)
}

# ── 5xx Error Rate (MQL ratio) ────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "apigee_error_rate_warning" {
  count        = var.apigee.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Apigee][WARNING] API Proxy 5xx Error Rate High"
  combiner     = "OR"
  user_labels  = merge(local.apigee_labels, local.severity_warning)

  conditions {
    display_name = "Apigee proxy 5xx error rate > ${var.apigee.error_rate_warning_threshold * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch apigee.googleapis.com/ProxyV2
        | metric 'apigee.googleapis.com/proxy/request_count'
        | align rate(1m)
        | group_by [resource.labels.proxy_name],
            [val: sum(if(metric.labels.response_code >= 500, val(), 0)) / sum(val())]
        | condition val() > ${var.apigee.error_rate_warning_threshold}
      EOT
      duration = "${var.apigee.duration_warning_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Apigee API proxy 5xx error rate has exceeded ${var.apigee.error_rate_warning_threshold * 100}%. Check proxy policies and backend target health. ${var.alert_documentation_prefix}/runbooks/apigee-errors"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "apigee_error_rate_critical" {
  count        = var.apigee.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Apigee][CRITICAL] API Proxy 5xx Error Rate Critical"
  combiner     = "OR"
  user_labels  = merge(local.apigee_labels, local.severity_critical)

  conditions {
    display_name = "Apigee proxy 5xx error rate > ${var.apigee.error_rate_critical_threshold * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch apigee.googleapis.com/ProxyV2
        | metric 'apigee.googleapis.com/proxy/request_count'
        | align rate(1m)
        | group_by [resource.labels.proxy_name],
            [val: sum(if(metric.labels.response_code >= 500, val(), 0)) / sum(val())]
        | condition val() > ${var.apigee.error_rate_critical_threshold}
      EOT
      duration = "${var.apigee.duration_critical_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Apigee API proxy 5xx error rate has exceeded ${var.apigee.error_rate_critical_threshold * 100}%. API gateway is severely degraded. ${var.alert_documentation_prefix}/runbooks/apigee-errors"
    mime_type = "text/markdown"
  }
}

# ── Proxy Response Latency P99 ────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "apigee_latency_warning" {
  count        = var.apigee.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Apigee][WARNING] API Proxy Response Latency High"
  combiner     = "OR"
  user_labels  = merge(local.apigee_labels, local.severity_warning)

  conditions {
    display_name = "Proxy P99 response latency > ${var.apigee.latency_p99_warning_ms}ms"
    condition_threshold {
      filter          = "${local.apigee_base_filter} AND metric.type=\"apigee.googleapis.com/proxy/response_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.apigee.latency_p99_warning_ms
      duration        = "${var.apigee.duration_warning_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.proxy_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Apigee API proxy P99 response latency has exceeded ${var.apigee.latency_p99_warning_ms}ms. Check proxy policies for slow operations or target backend performance. ${var.alert_documentation_prefix}/runbooks/apigee-latency"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "apigee_latency_critical" {
  count        = var.apigee.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Apigee][CRITICAL] API Proxy Response Latency Critical"
  combiner     = "OR"
  user_labels  = merge(local.apigee_labels, local.severity_critical)

  conditions {
    display_name = "Proxy P99 response latency > ${var.apigee.latency_p99_critical_ms}ms"
    condition_threshold {
      filter          = "${local.apigee_base_filter} AND metric.type=\"apigee.googleapis.com/proxy/response_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.apigee.latency_p99_critical_ms
      duration        = "${var.apigee.duration_critical_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.proxy_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Apigee API proxy latency is critically high at P99 > ${var.apigee.latency_p99_critical_ms}ms. API consumers are severely impacted. ${var.alert_documentation_prefix}/runbooks/apigee-latency"
    mime_type = "text/markdown"
  }
}

# ── Quota Violations ──────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "apigee_quota_violations_warning" {
  count        = var.apigee.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Apigee][WARNING] API Quota Violations High"
  combiner     = "OR"
  user_labels  = merge(local.apigee_labels, local.severity_warning)

  conditions {
    display_name = "Quota violations > ${var.apigee.quota_violation_warning}/hour"
    condition_threshold {
      filter          = "${local.apigee_base_filter} AND metric.type=\"apigee.googleapis.com/proxy/quota_count\" AND metric.labels.quota_type=\"VIOLATED\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.apigee.quota_violation_warning
      duration        = "${var.apigee.duration_warning_secs}s"
      aggregations {
        alignment_period     = "3600s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.proxy_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Apigee API quota violations have exceeded ${var.apigee.quota_violation_warning}/hour. Clients are being rate-limited. Review quota policies and client usage patterns. ${var.alert_documentation_prefix}/runbooks/apigee-quota"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "apigee_quota_violations_critical" {
  count        = var.apigee.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Apigee][CRITICAL] API Quota Violations Critical"
  combiner     = "OR"
  user_labels  = merge(local.apigee_labels, local.severity_critical)

  conditions {
    display_name = "Quota violations > ${var.apigee.quota_violation_critical}/hour"
    condition_threshold {
      filter          = "${local.apigee_base_filter} AND metric.type=\"apigee.googleapis.com/proxy/quota_count\" AND metric.labels.quota_type=\"VIOLATED\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.apigee.quota_violation_critical
      duration        = "${var.apigee.duration_critical_secs}s"
      aggregations {
        alignment_period     = "3600s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.proxy_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Apigee API quota violations are critical at ${var.apigee.quota_violation_critical}/hour. Many clients are being blocked. Review API monetization policies or increase quotas. ${var.alert_documentation_prefix}/runbooks/apigee-quota"
    mime_type = "text/markdown"
  }
}
