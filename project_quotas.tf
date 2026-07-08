locals {
  quota_labels = merge(local.common_labels, { service = "project-quotas" }, var.project_quotas.labels)
}

# ── Quota Allocation Usage ────────────────────────────────────────────────────
# Alerts when any quota metric's allocation usage exceeds the threshold.
# GCP resource type: consumer_quota
# Metric: serviceruntime.googleapis.com/quota/allocation/usage

resource "google_monitoring_alert_policy" "quota_allocation_warning" {
  count        = var.project_quotas.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Quota][WARNING] Allocation Quota Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.quota_labels, local.severity_warning)

  conditions {
    display_name = "Quota allocation usage > ${var.project_quotas.allocation_warning_threshold * 100}% of limit"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch consumer_quota
        | metric 'serviceruntime.googleapis.com/quota/allocation/usage'
        | group_by [resource.labels.quota_metric, resource.labels.service],
            [usage: mean(val())]
        | join (
            fetch consumer_quota
            | metric 'serviceruntime.googleapis.com/quota/limit'
            | group_by [resource.labels.quota_metric, resource.labels.service],
                [limit: mean(val())]
          )
        | value if(limit > 0, usage / limit, 0)
        | condition val() > ${var.project_quotas.allocation_warning_threshold}
      EOT
      duration = "${var.project_quotas.duration_warning_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "A GCP project quota has exceeded ${var.project_quotas.allocation_warning_threshold * 100}% of its limit. Review quota usage in the GCP console under IAM & Admin > Quotas. Request quota increases in advance to prevent service disruptions. ${var.alert_documentation_prefix}/runbooks/project-quotas"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "quota_allocation_critical" {
  count        = var.project_quotas.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Quota][CRITICAL] Allocation Quota Near Exhaustion"
  combiner     = "OR"
  user_labels  = merge(local.quota_labels, local.severity_critical)

  conditions {
    display_name = "Quota allocation usage > ${var.project_quotas.allocation_critical_threshold * 100}% of limit"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch consumer_quota
        | metric 'serviceruntime.googleapis.com/quota/allocation/usage'
        | group_by [resource.labels.quota_metric, resource.labels.service],
            [usage: mean(val())]
        | join (
            fetch consumer_quota
            | metric 'serviceruntime.googleapis.com/quota/limit'
            | group_by [resource.labels.quota_metric, resource.labels.service],
                [limit: mean(val())]
          )
        | value if(limit > 0, usage / limit, 0)
        | condition val() > ${var.project_quotas.allocation_critical_threshold}
      EOT
      duration = "${var.project_quotas.duration_critical_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "A GCP project quota has exceeded ${var.project_quotas.allocation_critical_threshold * 100}% of its limit. New resource allocations of this type will be rejected. Submit a quota increase request immediately. ${var.alert_documentation_prefix}/runbooks/project-quotas"
    mime_type = "text/markdown"
  }
}

# ── Quota Rate Usage ──────────────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "quota_rate_warning" {
  count        = var.project_quotas.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Quota][WARNING] API Rate Quota Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.quota_labels, local.severity_warning)

  conditions {
    display_name = "Quota rate usage > ${var.project_quotas.rate_warning_threshold * 100}% of limit"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch consumer_quota
        | metric 'serviceruntime.googleapis.com/quota/rate/net_usage'
        | group_by [resource.labels.quota_metric, resource.labels.service],
            [usage: mean(val())]
        | join (
            fetch consumer_quota
            | metric 'serviceruntime.googleapis.com/quota/limit'
            | group_by [resource.labels.quota_metric, resource.labels.service],
                [limit: mean(val())]
          )
        | value if(limit > 0, usage / limit, 0)
        | condition val() > ${var.project_quotas.rate_warning_threshold}
      EOT
      duration = "${var.project_quotas.duration_warning_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "A GCP API rate quota has exceeded ${var.project_quotas.rate_warning_threshold * 100}% of its limit. API calls may be throttled if usage continues to grow. ${var.alert_documentation_prefix}/runbooks/project-quotas"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "quota_rate_critical" {
  count        = var.project_quotas.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[Quota][CRITICAL] API Rate Quota Near Limit"
  combiner     = "OR"
  user_labels  = merge(local.quota_labels, local.severity_critical)

  conditions {
    display_name = "Quota rate usage > ${var.project_quotas.rate_critical_threshold * 100}% of limit"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch consumer_quota
        | metric 'serviceruntime.googleapis.com/quota/rate/net_usage'
        | group_by [resource.labels.quota_metric, resource.labels.service],
            [usage: mean(val())]
        | join (
            fetch consumer_quota
            | metric 'serviceruntime.googleapis.com/quota/limit'
            | group_by [resource.labels.quota_metric, resource.labels.service],
                [limit: mean(val())]
          )
        | value if(limit > 0, usage / limit, 0)
        | condition val() > ${var.project_quotas.rate_critical_threshold}
      EOT
      duration = "${var.project_quotas.duration_critical_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "A GCP API rate quota is critically near its limit at ${var.project_quotas.rate_critical_threshold * 100}%. API requests are being throttled or will be shortly. Submit an emergency quota increase request. ${var.alert_documentation_prefix}/runbooks/project-quotas"
    mime_type = "text/markdown"
  }
}
