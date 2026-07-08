locals {
  lb_rule_filter = var.load_balancer.forwarding_rule_filter != null ? " AND resource.labels.forwarding_rule_name=~\"${var.load_balancer.forwarding_rule_filter}\"" : ""
  lb_base_filter = "resource.type=\"https_lb_rule\"${local.lb_rule_filter}"
  lb_labels      = merge(local.common_labels, { service = "load-balancer" }, var.load_balancer.labels)
}

# ── 5xx Error Rate (MQL ratio) ────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "lb_error_rate_warning" {
  count        = var.load_balancer.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[LB][WARNING] HTTP 5xx Error Rate High"
  combiner     = "OR"
  user_labels  = merge(local.lb_labels, local.severity_warning)

  conditions {
    display_name = "HTTP 5xx error rate > ${var.load_balancer.error_rate_warning_threshold * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch https_lb_rule
        | metric 'loadbalancing.googleapis.com/https/request_count'
        | align rate(1m)
        | group_by [resource.labels.forwarding_rule_name],
            [val: sum(if(metric.labels.response_code_class = "500", val(), 0)) / sum(val())]
        | condition val() > ${var.load_balancer.error_rate_warning_threshold}
      EOT
      duration = "${var.load_balancer.duration_warning_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Load balancer 5xx error rate has exceeded ${var.load_balancer.error_rate_warning_threshold * 100}%. Check backend health and application logs. ${var.alert_documentation_prefix}/runbooks/lb-errors"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "lb_error_rate_critical" {
  count        = var.load_balancer.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[LB][CRITICAL] HTTP 5xx Error Rate Critical"
  combiner     = "OR"
  user_labels  = merge(local.lb_labels, local.severity_critical)

  conditions {
    display_name = "HTTP 5xx error rate > ${var.load_balancer.error_rate_critical_threshold * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch https_lb_rule
        | metric 'loadbalancing.googleapis.com/https/request_count'
        | align rate(1m)
        | group_by [resource.labels.forwarding_rule_name],
            [val: sum(if(metric.labels.response_code_class = "500", val(), 0)) / sum(val())]
        | condition val() > ${var.load_balancer.error_rate_critical_threshold}
      EOT
      duration = "${var.load_balancer.duration_critical_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Load balancer 5xx error rate has exceeded ${var.load_balancer.error_rate_critical_threshold * 100}%. Service is severely degraded. Check backend pool health immediately. ${var.alert_documentation_prefix}/runbooks/lb-errors"
    mime_type = "text/markdown"
  }
}

# ── Backend Latency P95 ───────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "lb_backend_latency_warning" {
  count        = var.load_balancer.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[LB][WARNING] Backend Latency P95 High"
  combiner     = "OR"
  user_labels  = merge(local.lb_labels, local.severity_warning)

  conditions {
    display_name = "Backend P95 latency > ${var.load_balancer.latency_p95_warning_ms}ms"
    condition_threshold {
      filter          = "${local.lb_base_filter} AND metric.type=\"loadbalancing.googleapis.com/https/backend_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.load_balancer.latency_p95_warning_ms
      duration        = "${var.load_balancer.duration_warning_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.forwarding_rule_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Load balancer backend P95 latency has exceeded ${var.load_balancer.latency_p95_warning_ms}ms. Check backend service performance and connection pool settings. ${var.alert_documentation_prefix}/runbooks/lb-latency"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "lb_backend_latency_critical" {
  count        = var.load_balancer.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[LB][CRITICAL] Backend Latency P95 Critical"
  combiner     = "OR"
  user_labels  = merge(local.lb_labels, local.severity_critical)

  conditions {
    display_name = "Backend P95 latency > ${var.load_balancer.latency_p95_critical_ms}ms"
    condition_threshold {
      filter          = "${local.lb_base_filter} AND metric.type=\"loadbalancing.googleapis.com/https/backend_latencies\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.load_balancer.latency_p95_critical_ms
      duration        = "${var.load_balancer.duration_critical_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_95"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.forwarding_rule_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Load balancer backend P95 latency has exceeded ${var.load_balancer.latency_p95_critical_ms}ms. End users are experiencing severe latency. ${var.alert_documentation_prefix}/runbooks/lb-latency"
    mime_type = "text/markdown"
  }
}

# ── SSL Certificate Expiry ────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "lb_ssl_expiry_warning" {
  count        = var.load_balancer.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[LB][WARNING] SSL Certificate Expiring Soon"
  combiner     = "OR"
  user_labels  = merge(local.lb_labels, local.severity_warning)

  conditions {
    display_name = "SSL certificate expires in < ${var.load_balancer.ssl_expiry_warning_days} days"
    condition_threshold {
      filter          = "resource.type=\"uptime_url\" AND metric.type=\"monitoring.googleapis.com/uptime_check/time_until_ssl_cert_expires\""
      comparison      = "COMPARISON_LT"
      threshold_value = var.load_balancer.ssl_expiry_warning_days * 86400
      duration        = "${var.load_balancer.duration_warning_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "An SSL certificate monitored by an uptime check will expire within ${var.load_balancer.ssl_expiry_warning_days} days. Renew the certificate before it expires to avoid HTTPS failures. ${var.alert_documentation_prefix}/runbooks/ssl-certificate"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "lb_ssl_expiry_critical" {
  count        = var.load_balancer.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[LB][CRITICAL] SSL Certificate Expiry Imminent"
  combiner     = "OR"
  user_labels  = merge(local.lb_labels, local.severity_critical)

  conditions {
    display_name = "SSL certificate expires in < ${var.load_balancer.ssl_expiry_critical_days} days"
    condition_threshold {
      filter          = "resource.type=\"uptime_url\" AND metric.type=\"monitoring.googleapis.com/uptime_check/time_until_ssl_cert_expires\""
      comparison      = "COMPARISON_LT"
      threshold_value = var.load_balancer.ssl_expiry_critical_days * 86400
      duration        = "${var.load_balancer.duration_critical_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "An SSL certificate will expire within ${var.load_balancer.ssl_expiry_critical_days} days. HTTPS traffic will fail after expiry. Renew immediately. ${var.alert_documentation_prefix}/runbooks/ssl-certificate"
    mime_type = "text/markdown"
  }
}
