locals {
  mig_group_filter  = var.mig.instance_group_filter != null ? " AND resource.labels.instance_group_name=~\"${var.mig.instance_group_filter}\"" : ""
  mig_labels        = merge(local.common_labels, { service = "mig" }, var.mig.labels)
}

# ── Autoscaler Target Utilisation ─────────────────────────────────────────────

resource "google_monitoring_alert_policy" "mig_autoscaler_warning" {
  count        = var.mig.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[MIG][WARNING] Autoscaler Capacity Utilisation High"
  combiner     = "OR"
  user_labels  = merge(local.mig_labels, local.severity_warning)

  conditions {
    display_name = "Autoscaler capacity utilisation > ${var.mig.autoscaler_utilization_warning * 100}%"
    condition_threshold {
      filter          = "resource.type=\"autoscaler\"${local.mig_group_filter} AND metric.type=\"autoscaler.googleapis.com/capacity/target_utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.mig.autoscaler_utilization_warning
      duration        = "${var.mig.duration_warning_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "MIG autoscaler target utilisation has exceeded ${var.mig.autoscaler_utilization_warning * 100}%. The autoscaler is actively scaling up. Review peak capacity planning. ${var.alert_documentation_prefix}/runbooks/mig-autoscaler"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "mig_autoscaler_critical" {
  count        = var.mig.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[MIG][CRITICAL] Autoscaler At Capacity Limit"
  combiner     = "OR"
  user_labels  = merge(local.mig_labels, local.severity_critical)

  conditions {
    display_name = "Autoscaler capacity utilisation > ${var.mig.autoscaler_utilization_critical * 100}%"
    condition_threshold {
      filter          = "resource.type=\"autoscaler\"${local.mig_group_filter} AND metric.type=\"autoscaler.googleapis.com/capacity/target_utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.mig.autoscaler_utilization_critical
      duration        = "${var.mig.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "MIG autoscaler is at or near its maximum capacity limit (${var.mig.autoscaler_utilization_critical * 100}%). New requests may be rejected. Increase max-instances or review load. ${var.alert_documentation_prefix}/runbooks/mig-autoscaler"
    mime_type = "text/markdown"
  }
}

# ── Unhealthy Instance Ratio (MQL) ────────────────────────────────────────────

resource "google_monitoring_alert_policy" "mig_unhealthy_instances_warning" {
  count        = var.mig.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[MIG][WARNING] Unhealthy Instances Detected"
  combiner     = "OR"
  user_labels  = merge(local.mig_labels, local.severity_warning)

  conditions {
    display_name = "Unhealthy instance ratio > ${var.mig.unhealthy_ratio_warning * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        {
          fetch instance_group
          | metric 'compute.googleapis.com/instance_group/size'
          | group_by [resource.labels.instance_group_name], [total: mean(val())]
        ;
          fetch instance_group
          | metric 'compute.googleapis.com/instance_group/healthy_instances'
          | group_by [resource.labels.instance_group_name], [healthy: mean(val())]
        }
        | join
        | value if(total > 0, (total - healthy) / total, 0)
        | condition val() > ${var.mig.unhealthy_ratio_warning}
      EOT
      duration = "${var.mig.duration_warning_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "More than ${var.mig.unhealthy_ratio_warning * 100}% of MIG instances are unhealthy. This reduces serving capacity. Check instance health and startup scripts. ${var.alert_documentation_prefix}/runbooks/mig-health"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "mig_unhealthy_instances_critical" {
  count        = var.mig.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[MIG][CRITICAL] High Proportion of Unhealthy Instances"
  combiner     = "OR"
  user_labels  = merge(local.mig_labels, local.severity_critical)

  conditions {
    display_name = "Unhealthy instance ratio > ${var.mig.unhealthy_ratio_critical * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        {
          fetch instance_group
          | metric 'compute.googleapis.com/instance_group/size'
          | group_by [resource.labels.instance_group_name], [total: mean(val())]
        ;
          fetch instance_group
          | metric 'compute.googleapis.com/instance_group/healthy_instances'
          | group_by [resource.labels.instance_group_name], [healthy: mean(val())]
        }
        | join
        | value if(total > 0, (total - healthy) / total, 0)
        | condition val() > ${var.mig.unhealthy_ratio_critical}
      EOT
      duration = "${var.mig.duration_critical_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "More than ${var.mig.unhealthy_ratio_critical * 100}% of MIG instances are unhealthy. Serving capacity is severely reduced. Investigate instance startup failures and health check configuration. ${var.alert_documentation_prefix}/runbooks/mig-health"
    mime_type = "text/markdown"
  }
}
