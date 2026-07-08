locals {
  armor_policy_filter = var.cloud_armor.security_policy_filter != null ? " AND resource.labels.policy_name=~\"${var.cloud_armor.security_policy_filter}\"" : ""
  armor_base_filter   = "resource.type=\"network_security_policy\"${local.armor_policy_filter}"
  armor_labels        = merge(local.common_labels, { service = "cloud-armor" }, var.cloud_armor.labels)
}

# ── Denied Requests Rate ──────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "armor_denied_requests_warning" {
  count        = var.cloud_armor.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudArmor][WARNING] Denied Requests Rate High"
  combiner     = "OR"
  user_labels  = merge(local.armor_labels, local.severity_warning)

  conditions {
    display_name = "Denied requests > ${var.cloud_armor.denied_requests_warning}/min"
    condition_threshold {
      filter          = "${local.armor_base_filter} AND metric.type=\"networksecurity.googleapis.com/https/request_count\" AND metric.labels.blocked=\"true\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_armor.denied_requests_warning
      duration        = "${var.cloud_armor.duration_warning_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.policy_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud Armor is denying more than ${var.cloud_armor.denied_requests_warning} requests per minute. This may indicate a misconfigured rule blocking legitimate traffic or an active attack. ${var.alert_documentation_prefix}/runbooks/cloud-armor-denied"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "armor_denied_requests_critical" {
  count        = var.cloud_armor.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudArmor][CRITICAL] Denied Requests Rate Critical"
  combiner     = "OR"
  user_labels  = merge(local.armor_labels, local.severity_critical)

  conditions {
    display_name = "Denied requests > ${var.cloud_armor.denied_requests_critical}/min"
    condition_threshold {
      filter          = "${local.armor_base_filter} AND metric.type=\"networksecurity.googleapis.com/https/request_count\" AND metric.labels.blocked=\"true\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.cloud_armor.denied_requests_critical
      duration        = "${var.cloud_armor.duration_critical_secs}s"
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.policy_name"]
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud Armor is denying more than ${var.cloud_armor.denied_requests_critical} requests per minute. Potential DDoS attack or major rule misconfiguration. Review Adaptive Protection findings and Cloud Armor logs. ${var.alert_documentation_prefix}/runbooks/cloud-armor-denied"
    mime_type = "text/markdown"
  }
}

# ── Allowed Request Volume Spike (DDoS indicator) ─────────────────────────────

resource "google_monitoring_alert_policy" "armor_allowed_spike_warning" {
  count        = var.cloud_armor.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CloudArmor][WARNING] Allowed Request Volume Spike"
  combiner     = "OR"
  user_labels  = merge(local.armor_labels, local.severity_warning)

  conditions {
    display_name = "Allowed requests rate is abnormally high (potential DDoS bypassing rules)"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch network_security_policy
        | metric 'networksecurity.googleapis.com/https/request_count'
        | filter metric.labels.blocked = 'false'
        | align rate(1m)
        | group_by [resource.labels.policy_name], [val: sum(val())]
        | condition val() > 10000
      EOT
      duration = "${var.cloud_armor.duration_warning_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Cloud Armor is allowing an unusually high volume of requests. This may indicate a volumetric attack that is bypassing WAF rules. Review Adaptive Protection and consider enabling rate limiting rules. ${var.alert_documentation_prefix}/runbooks/cloud-armor-spike"
    mime_type = "text/markdown"
  }
}
