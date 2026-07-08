locals {
  cert_manager_labels = merge(local.common_labels, { service = "certificate-manager" }, var.certificate_manager.labels)
}

# ── Certificate Expiry via Uptime Check ───────────────────────────────────────
# Note: This alert fires on SSL certificates monitored via Cloud Monitoring
# uptime checks. Uptime checks must be configured separately to target your
# load balancer endpoints or HTTPS domains.

resource "google_monitoring_alert_policy" "cert_expiry_warning" {
  count        = var.certificate_manager.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CertManager][WARNING] Certificate Expiring Soon"
  combiner     = "OR"
  user_labels  = merge(local.cert_manager_labels, local.severity_warning)

  conditions {
    display_name = "SSL certificate expires in < ${var.certificate_manager.expiry_warning_days} days"
    condition_threshold {
      filter          = "resource.type=\"uptime_url\" AND metric.type=\"monitoring.googleapis.com/uptime_check/time_until_ssl_cert_expires\""
      comparison      = "COMPARISON_LT"
      threshold_value = var.certificate_manager.expiry_warning_days * 86400
      duration        = "${var.certificate_manager.duration_warning_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "An SSL certificate will expire within ${var.certificate_manager.expiry_warning_days} days. Renew the certificate before it expires to avoid HTTPS failures. For Google-managed certificates, verify the Certificate Manager status in the console. ${var.alert_documentation_prefix}/runbooks/certificate-expiry"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "cert_expiry_critical" {
  count        = var.certificate_manager.enabled ? 1 : 0
  project      = var.project_id
  display_name = "[CertManager][CRITICAL] Certificate Expiry Imminent"
  combiner     = "OR"
  user_labels  = merge(local.cert_manager_labels, local.severity_critical)

  conditions {
    display_name = "SSL certificate expires in < ${var.certificate_manager.expiry_critical_days} days"
    condition_threshold {
      filter          = "resource.type=\"uptime_url\" AND metric.type=\"monitoring.googleapis.com/uptime_check/time_until_ssl_cert_expires\""
      comparison      = "COMPARISON_LT"
      threshold_value = var.certificate_manager.expiry_critical_days * 86400
      duration        = "${var.certificate_manager.duration_critical_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "An SSL certificate expires within ${var.certificate_manager.expiry_critical_days} days. HTTPS traffic will fail after expiry. Immediate renewal required. For Google-managed certificates, check if auto-renewal is failing due to DNS/HTTP validation issues. ${var.alert_documentation_prefix}/runbooks/certificate-expiry"
    mime_type = "text/markdown"
  }
}

# ── Certificate Provisioning Failure (Log-based) ──────────────────────────────

resource "google_logging_metric" "cert_provisioning_failure" {
  count   = var.certificate_manager.enabled ? 1 : 0
  project = var.project_id
  name    = "certificate_manager_provisioning_failure"

  filter = <<-EOT
    resource.type="audited_resource"
    protoPayload.serviceName="certificatemanager.googleapis.com"
    protoPayload.status.code!=0
    severity=ERROR
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

resource "google_monitoring_alert_policy" "cert_provisioning_failure" {
  count      = var.certificate_manager.enabled ? 1 : 0
  project    = var.project_id
  depends_on = [google_logging_metric.cert_provisioning_failure]

  display_name = "[CertManager][WARNING] Certificate Provisioning Failed"
  combiner     = "OR"
  user_labels  = merge(local.cert_manager_labels, local.severity_warning)

  conditions {
    display_name = "Certificate Manager provisioning error detected"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.cert_provisioning_failure[0].name}\" AND resource.type=\"audited_resource\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "${var.certificate_manager.duration_warning_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Certificate Manager has encountered an error during certificate provisioning or renewal. Check the Certificate Manager console for certificates in FAILED or PROVISIONING state. Verify DNS or HTTP validation records are correctly configured. ${var.alert_documentation_prefix}/runbooks/certificate-provisioning"
    mime_type = "text/markdown"
  }
}
