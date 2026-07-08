locals {
  ncc_hub_filter = var.ncc.hub_name_filter != null ? " AND resource.labels.hub_id=~\"${var.ncc.hub_name_filter}\"" : ""
  ncc_labels     = merge(local.common_labels, { service = "ncc" }, var.ncc.labels)
}

# ── NCC Spoke State Change (Log-based) ───────────────────────────────────────

resource "google_logging_metric" "ncc_spoke_inactive" {
  count   = var.ncc.enabled ? 1 : 0
  project = var.project_id
  name    = "ncc_spoke_inactive"

  filter = <<-EOT
    resource.type="audited_resource"
    protoPayload.serviceName="networkconnectivity.googleapis.com"
    (protoPayload.methodName=~"networkconnectivity.googleapis.com.HubService.UpdateSpoke" OR
     protoPayload.methodName=~"networkconnectivity.googleapis.com.HubService.DeleteSpoke")
    protoPayload.status.code!=0
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

resource "google_monitoring_alert_policy" "ncc_spoke_state_warning" {
  count      = var.ncc.enabled ? 1 : 0
  project    = var.project_id
  depends_on = [google_logging_metric.ncc_spoke_inactive]

  display_name = "[NCC][WARNING] Spoke State Change or Error Detected"
  combiner     = "OR"
  user_labels  = merge(local.ncc_labels, local.severity_warning)

  conditions {
    display_name = "NCC spoke operation errors detected"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.ncc_spoke_inactive[0].name}\" AND resource.type=\"audited_resource\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "${var.ncc.duration_warning_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "NCC spoke state change or error has been detected. This may indicate a connectivity disruption between spoke VPCs and the NCC hub. Check the NCC console for spoke status. ${var.alert_documentation_prefix}/runbooks/ncc-spoke"
    mime_type = "text/markdown"
  }
}

# ── Hub Data Plane Throughput ─────────────────────────────────────────────────

resource "google_monitoring_alert_policy" "ncc_hub_throughput_warning" {
  count        = var.ncc.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[NCC][WARNING] Hub Data Plane Throughput High"
  combiner     = "OR"
  user_labels  = merge(local.ncc_labels, local.severity_warning)

  conditions {
    display_name = "NCC hub data plane utilisation > ${var.ncc.throughput_warning_threshold * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch networkconnectivity.googleapis.com/Hub
        | metric 'networkconnectivity.googleapis.com/hub/data_plane_mbps'
        | group_by [resource.labels.hub_id], [val: mean(val())]
        | condition val() > ${var.ncc.throughput_warning_threshold * 10000}
      EOT
      duration = "${var.ncc.duration_warning_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "NCC hub data plane throughput is at ${var.ncc.throughput_warning_threshold * 100}% of capacity. Review traffic patterns and consider hub capacity planning. ${var.alert_documentation_prefix}/runbooks/ncc-throughput"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "ncc_hub_throughput_critical" {
  count        = var.ncc.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[NCC][CRITICAL] Hub Data Plane Throughput Critical"
  combiner     = "OR"
  user_labels  = merge(local.ncc_labels, local.severity_critical)

  conditions {
    display_name = "NCC hub data plane utilisation > ${var.ncc.throughput_critical_threshold * 100}%"
    condition_monitoring_query_language {
      query = <<-EOT
        fetch networkconnectivity.googleapis.com/Hub
        | metric 'networkconnectivity.googleapis.com/hub/data_plane_mbps'
        | group_by [resource.labels.hub_id], [val: mean(val())]
        | condition val() > ${var.ncc.throughput_critical_threshold * 10000}
      EOT
      duration = "${var.ncc.duration_critical_secs}s"
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "NCC hub data plane throughput is critically high at ${var.ncc.throughput_critical_threshold * 100}% capacity. Network connectivity between spokes may degrade. ${var.alert_documentation_prefix}/runbooks/ncc-throughput"
    mime_type = "text/markdown"
  }
}

# ── BGP Session Down (Hybrid Spokes) ─────────────────────────────────────────

resource "google_monitoring_alert_policy" "ncc_bgp_session_down" {
  count        = var.ncc.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[NCC][CRITICAL] BGP Session Down on Hybrid Spoke"
  combiner     = "OR"
  user_labels  = merge(local.ncc_labels, local.severity_critical)

  conditions {
    display_name = "BGP session status is not established"
    condition_threshold {
      filter          = "resource.type=\"gce_router\" AND metric.type=\"router.googleapis.com/bgp/session_up\""
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "${var.ncc.duration_critical_secs}s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "A BGP session on a Cloud Router attached to an NCC hybrid spoke is down. On-premises connectivity via this spoke is disrupted. Check Cloud Router and on-premises BGP peer configuration. ${var.alert_documentation_prefix}/runbooks/ncc-bgp"
    mime_type = "text/markdown"
  }
}
