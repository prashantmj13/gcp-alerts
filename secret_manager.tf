locals {
  secret_manager_labels = merge(local.common_labels, { service = "secret-manager" }, var.secret_manager.labels)
}

# ── Access Denied (Log-based Metric) ─────────────────────────────────────────

resource "google_logging_metric" "secret_access_denied" {
  count   = var.secret_manager.enabled ? 1 : 0
  project = var.project_id
  name    = "secret_manager_access_denied"

  filter = <<-EOT
    resource.type="secretmanager.googleapis.com/Secret"
    protoPayload.serviceName="secretmanager.googleapis.com"
    protoPayload.status.code=7
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    labels {
      key        = "secret_id"
      value_type = "STRING"
    }
  }

  label_extractors = {
    "secret_id" = "EXTRACT(resource.labels.secret_id)"
  }
}

resource "google_monitoring_alert_policy" "secret_access_denied_warning" {
  count      = var.secret_manager.enabled ? 1 : 0
  project    = var.project_id
  depends_on = [google_logging_metric.secret_access_denied]

  display_name = "[SecretManager][WARNING] Access Denied Events Detected"
  combiner     = "OR"
  user_labels  = merge(local.secret_manager_labels, local.severity_warning)

  conditions {
    display_name = "Secret access denied > ${var.secret_manager.access_denied_warning} per hour"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.secret_access_denied[0].name}\" AND resource.type=\"secretmanager.googleapis.com/Secret\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.secret_manager.access_denied_warning
      duration        = "${var.secret_manager.duration_warning_secs}s"
      aggregations {
        alignment_period   = "3600s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Secret Manager has received ${var.secret_manager.access_denied_warning}+ access denied errors in the past hour. This may indicate a misconfigured service account or an unauthorized access attempt. Review IAM bindings and Cloud Audit Logs. ${var.alert_documentation_prefix}/runbooks/secret-manager-access"
    mime_type = "text/markdown"
  }
}

resource "google_monitoring_alert_policy" "secret_access_denied_critical" {
  count      = var.secret_manager.enabled ? 1 : 0
  project    = var.project_id
  depends_on = [google_logging_metric.secret_access_denied]

  display_name = "[SecretManager][CRITICAL] Repeated Access Denied — Potential Unauthorized Access"
  combiner     = "OR"
  user_labels  = merge(local.secret_manager_labels, local.severity_critical)

  conditions {
    display_name = "Secret access denied > ${var.secret_manager.access_denied_critical} per hour"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.secret_access_denied[0].name}\" AND resource.type=\"secretmanager.googleapis.com/Secret\""
      comparison      = "COMPARISON_GT"
      threshold_value = var.secret_manager.access_denied_critical
      duration        = "${var.secret_manager.duration_critical_secs}s"
      aggregations {
        alignment_period   = "3600s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "Secret Manager has received ${var.secret_manager.access_denied_critical}+ access denied errors in the past hour. This is a potential security incident. Investigate immediately using Cloud Audit Logs and review IAM policies. ${var.alert_documentation_prefix}/runbooks/secret-manager-access"
    mime_type = "text/markdown"
  }
}

# ── Secret Version Destroyed (Log-based) ─────────────────────────────────────

resource "google_logging_metric" "secret_version_destroyed" {
  count   = var.secret_manager.enabled ? 1 : 0
  project = var.project_id
  name    = "secret_manager_version_destroyed"

  filter = <<-EOT
    resource.type="secretmanager.googleapis.com/Secret"
    protoPayload.serviceName="secretmanager.googleapis.com"
    protoPayload.methodName="google.cloud.secretmanager.v1.SecretManagerService.DestroySecretVersion"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
  }
}

resource "google_monitoring_alert_policy" "secret_version_destroyed_warning" {
  count      = var.secret_manager.enabled ? 1 : 0
  project    = var.project_id
  depends_on = [google_logging_metric.secret_version_destroyed]

  display_name = "[SecretManager][WARNING] Secret Version Destroyed"
  combiner     = "OR"
  user_labels  = merge(local.secret_manager_labels, local.severity_warning)

  conditions {
    display_name = "Secret version destruction event detected"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.secret_version_destroyed[0].name}\" AND resource.type=\"secretmanager.googleapis.com/Secret\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "${var.secret_manager.duration_warning_secs}s"
      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = local.notification_channels
  alert_strategy { auto_close = "604800s" }

  documentation {
    content   = "A Secret Manager secret version has been permanently destroyed. If this was unintended, recovery is not possible. Review Cloud Audit Logs to identify who performed the action. ${var.alert_documentation_prefix}/runbooks/secret-manager-destruction"
    mime_type = "text/markdown"
  }
}
