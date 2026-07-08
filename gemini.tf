locals {
  gemini_labels = merge(local.common_labels, { service = "gemini-enterprise" }, var.gemini.labels)
}

# ── API Error Rate (MQL ratio) ────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "gemini_error_rate_warning" {
  count        = var.gemini.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Gemini][WARNING] API Error Rate High"
  combiner     = "OR"
  user_labels  = merge(local.gemini_labels, local.severity_warning)

  conditions {
    display_name = "Gemini API error rate > ${var.gemini.error_rate_warning_threshold * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch consumed_api
        | metric 'serviceruntime.googleapis.com/api/request_count'
        | filter resource.labels.service = 'cloudaicompanion.googleapis.com'
        | align rate(1m)
        | group_by [resource.labels.service],
            [val: sum(if(metric.labels.response_code_class = "5xx", val(), 0)) / sum(val())]
        | condition val() > ${var.gemini.error_rate_warning_threshold}
      EOT
      duration = "${var.gemini.duration_warning_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Gemini Enterprise API error rate has exceeded ${var.gemini.error_rate_warning_threshold * 100}%. Check service health at status.cloud.google.com and review API logs. ${var.alert_documentation_prefix}/runbooks/gemini-errors"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "gemini_error_rate_critical" {
  count        = var.gemini.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Gemini][CRITICAL] API Error Rate Critical"
  combiner     = "OR"
  user_labels  = merge(local.gemini_labels, local.severity_critical)

  conditions {
    display_name = "Gemini API error rate > ${var.gemini.error_rate_critical_threshold * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch consumed_api
        | metric 'serviceruntime.googleapis.com/api/request_count'
        | filter resource.labels.service = 'cloudaicompanion.googleapis.com'
        | align rate(1m)
        | group_by [resource.labels.service],
            [val: sum(if(metric.labels.response_code_class = "5xx", val(), 0)) / sum(val())]
        | condition val() > ${var.gemini.error_rate_critical_threshold}
      EOT
      duration = "${var.gemini.duration_critical_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Gemini Enterprise API error rate is critically high at ${var.gemini.error_rate_critical_threshold * 100}%. AI features are severely degraded. ${var.alert_documentation_prefix}/runbooks/gemini-errors"
    mime_type = "text/markdown"
  }
}

# ── Quota Consumption ─────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "gemini_quota_warning" {
  count        = var.gemini.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Gemini][WARNING] API Quota Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.gemini_labels, local.severity_warning)

  conditions {
    display_name = "Gemini quota utilisation > ${var.gemini.quota_warning_threshold * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch consumer_quota
        | metric 'serviceruntime.googleapis.com/quota/rate/net_usage'
        | filter resource.labels.service = 'cloudaicompanion.googleapis.com'
        | group_by [resource.labels.quota_metric],
            [val: mean(val())]
        | join (
            fetch consumer_quota
            | metric 'serviceruntime.googleapis.com/quota/limit'
            | filter resource.labels.service = 'cloudaicompanion.googleapis.com'
            | group_by [resource.labels.quota_metric], [limit: mean(val())]
          )
        | value if(limit > 0, val / limit, 0)
        | condition val() > ${var.gemini.quota_warning_threshold}
      EOT
      duration = "${var.gemini.duration_warning_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Gemini Enterprise API quota consumption has exceeded ${var.gemini.quota_warning_threshold * 100}%. Request throttling may occur. Review usage and request quota increases if needed. ${var.alert_documentation_prefix}/runbooks/gemini-quota"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "gemini_quota_critical" {
  count        = var.gemini.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Gemini][CRITICAL] API Quota Near Exhaustion"
  combiner     = "OR"
  user_labels  = merge(local.gemini_labels, local.severity_critical)

  conditions {
    display_name = "Gemini quota utilisation > ${var.gemini.quota_critical_threshold * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch consumer_quota
        | metric 'serviceruntime.googleapis.com/quota/rate/net_usage'
        | filter resource.labels.service = 'cloudaicompanion.googleapis.com'
        | group_by [resource.labels.quota_metric],
            [val: mean(val())]
        | join (
            fetch consumer_quota
            | metric 'serviceruntime.googleapis.com/quota/limit'
            | filter resource.labels.service = 'cloudaicompanion.googleapis.com'
            | group_by [resource.labels.quota_metric], [limit: mean(val())]
          )
        | value if(limit > 0, val / limit, 0)
        | condition val() > ${var.gemini.quota_critical_threshold}
      EOT
      duration = "${var.gemini.duration_critical_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Gemini Enterprise API quota is at ${var.gemini.quota_critical_threshold * 100}% utilisation. Requests will be throttled. Immediately request a quota increase from GCP support. ${var.alert_documentation_prefix}/runbooks/gemini-quota"
    mime_type = "text/markdown"
  }
}
